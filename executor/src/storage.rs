use std::{error::Error, path::Path};

use alloy::primitives::U256;
use rusqlite::{Connection, OptionalExtension};

/// Opens the executor's SQLite database, creating the database file if it does not exist.
pub(crate) fn open_database(database_path: &Path) -> Result<Connection, Box<dyn Error>> {
    let connection = Connection::open(database_path)?;

    Ok(connection)
}

/// Creates the executor's required database tables only if they do not already exist.
pub(crate) fn initialize_schema(connection: &Connection) -> Result<(), Box<dyn Error>> {
    connection.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS executor_state (
            chain_id INTEGER PRIMARY KEY,
            last_processed_block INTEGER
        );

        -- Store uint256 payment IDs as decimal text because SQLite INTEGER is signed 64-bit.
        CREATE TABLE IF NOT EXISTS candidate_payments (
            payment_id TEXT PRIMARY KEY NOT NULL
        );
        ",
    )?;

    Ok(())
}

/// Initializes the persisted chain ID or validates it against the configured chain.
pub(crate) fn initialize_chain_state(
    connection: &Connection,
    configured_chain_id: u64,
) -> Result<(), Box<dyn Error>> {
    // SQLite `INTEGER` is signed 64-bit so use a checked conversion to prevent silent narrowing.
    let configured_chain_id = i64::try_from(configured_chain_id)?;

    // `query_row` passes the returned row to the closure, which extracts `chain_id` as an `i64`.
    // `optional()` converts a missing row into `None` so a new database can initialize its state.
    let stored_chain_id = connection
        .query_row("SELECT chain_id FROM executor_state", [], |row| {
            // In `get<I, T>`, `I` is the column index/name type inferred from `"chain_id"`, while
            // `T` is the Rust type used to decode the column value which is `i64` here.
            row.get::<_, i64>("chain_id")
        })
        .optional()?;

    match stored_chain_id {
        Some(stored_chain_id) => {
            if stored_chain_id != configured_chain_id {
                return Err(format!(
                    "database chain ID {stored_chain_id} does not match configured chain ID {configured_chain_id}"
                )
                .into());
            }
        }
        None => {
            connection.execute(
                "INSERT INTO executor_state (chain_id, last_processed_block)
                 VALUES (?1, NULL)",
                [configured_chain_id],
            )?;
        }
    }

    Ok(())
}

/// Loads the last successfully processed block for the configured chain.
pub(crate) fn load_last_processed_block(
    connection: &Connection,
    chain_id: u64,
) -> Result<Option<u64>, Box<dyn Error>> {
    let chain_id = i64::try_from(chain_id)?;

    let last_processed_block = connection.query_row(
        "SELECT last_processed_block FROM executor_state WHERE chain_id = ?1",
        [chain_id],
        |row| row.get::<_, Option<i64>>("last_processed_block"),
    )?;

    match last_processed_block {
        Some(last_processed_block) => Ok(Some(u64::try_from(last_processed_block)?)),
        None => Ok(None),
    }
}

/// Saves the highest block that was successfully processed for the configured chain.
pub(crate) fn save_last_processed_block(
    connection: &Connection,
    chain_id: u64,
    last_processed_block: u64,
) -> Result<(), Box<dyn Error>> {
    let chain_id = i64::try_from(chain_id)?;
    let last_processed_block = i64::try_from(last_processed_block)?;

    let rows_updated = connection.execute(
        "UPDATE executor_state SET last_processed_block = ?1 WHERE chain_id = ?2",
        [last_processed_block, chain_id],
    )?;

    if rows_updated != 1 {
        return Err(
            format!("expected to update one executor_state row, updated {rows_updated}").into(),
        );
    }

    Ok(())
}

/// Inserts `payment_id` into candidate storage if it is not already present.
pub(crate) fn insert_candidate(
    connection: &Connection,
    payment_id: U256,
) -> Result<(), Box<dyn Error>> {
    // Store the full `uint256` identifier as decimal text because SQLite `INTEGER` is signed
    // 64-bit.
    let payment_id = payment_id.to_string();

    connection.execute(
        "INSERT INTO candidate_payments (payment_id)
         VALUES (?1)
         ON CONFLICT(payment_id) DO NOTHING",
        [payment_id],
    )?;

    Ok(())
}

/// Loads all persisted candidate payment IDs.
pub(crate) fn load_candidates(connection: &Connection) -> Result<Vec<U256>, Box<dyn Error>> {
    // Prepare the SQL statement by borrowing the `Connection` for a compiler-inferred lifetime, so
    // it can't outlive the connection it uses.
    let mut statement = connection.prepare("SELECT payment_id FROM candidate_payments")?;
    // `MappedRows` owns both the mapping closure, and the `Rows` value returned by the internal
    // `query()` call. Because `Rows` borrows the prepared `Statement`, `MappedRows` must carry
    // the same lifetime.
    let rows = statement.query_map([], |row| row.get::<_, String>("payment_id"))?;

    let mut candidates = Vec::new();
    // Each time iteration advances, `MappedRows` asks its internal `Rows` value for the next
    // borrowed `&Row`, then calls `F(&Row)` so the closure can extract that row's `payment_id`.
    for row in rows {
        let payment_id = row?;
        // Candidate IDs are stored as canonical decimal text, so parse them back into `U256`. A
        // radix of `10` means the text is interpreted as base-10 decimal.
        let payment_id = U256::from_str_radix(&payment_id, 10)?;

        candidates.push(payment_id);
    }

    Ok(candidates)
}

/// Removes `payment_id` from candidate storage if it is present.
pub(crate) fn remove_candidate(
    connection: &Connection,
    payment_id: U256,
) -> Result<(), Box<dyn Error>> {
    // Candidate IDs are stored as canonical decimal text, so convert `payment_id` to the same
    // representation used by candidate storage.
    let payment_id = payment_id.to_string();

    connection.execute(
        "DELETE FROM candidate_payments WHERE payment_id = ?1",
        [payment_id],
    )?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // Verifies that a fresh database stores the configured chain ID.
    #[test]
    fn fresh_database_initializes_chain_id() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        let stored_chain_id: i64 =
            connection.query_row("SELECT chain_id FROM executor_state", [], |row| {
                row.get("chain_id")
            })?;

        assert_eq!(stored_chain_id, 421614);

        Ok(())
    }

    // Verifies that reinitializing with the same chain ID succeeds without creating duplicate
    // state.
    #[test]
    fn matching_chain_id_is_accepted() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;
        initialize_chain_state(&connection, 421614)?;

        // `COUNT(*)` returns one result row whose first column contains the total row count.
        let row_count: i64 =
            connection.query_row("SELECT COUNT(*) FROM executor_state", [], |row| row.get(0))?;

        assert_eq!(row_count, 1);

        Ok(())
    }

    // Verifies that persisted state cannot be reused with a different configured chain ID.
    #[test]
    fn mismatched_chain_id_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        let result = initialize_chain_state(&connection, 42161);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that validating an existing chain does not reset its saved checkpoint.
    #[test]
    fn reinitializing_chain_preserves_checkpoint() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;
        save_last_processed_block(&connection, 421614, 316206159)?;

        initialize_chain_state(&connection, 421614)?;

        let last_processed_block = load_last_processed_block(&connection, 421614)?;

        assert_eq!(last_processed_block, Some(316206159));

        Ok(())
    }

    // Verifies that values too large for SQLite `INTEGER` fail instead of being silently narrowed.
    #[test]
    fn oversized_chain_id_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        let result = initialize_chain_state(&connection, u64::MAX);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that a negative persisted chain ID is rejected because chain IDs are unsigned.
    #[test]
    fn negative_stored_chain_id_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        connection.execute(
            "INSERT INTO executor_state (chain_id, last_processed_block) VALUES (-1, NULL)",
            [],
        )?;

        let result = initialize_chain_state(&connection, 421614);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that a newly initialized chain has no `last_processed_block` checkpoint.
    #[test]
    fn fresh_chain_has_no_last_processed_block() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        let last_processed_block = load_last_processed_block(&connection, 421614)?;

        assert_eq!(last_processed_block, None);

        Ok(())
    }

    // Verifies that a saved `last_processed_block` checkpoint is loaded back correctly.
    #[test]
    fn saved_last_processed_block_is_loaded() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        save_last_processed_block(&connection, 421614, 316206159)?;

        let last_processed_block = load_last_processed_block(&connection, 421614)?;

        assert_eq!(last_processed_block, Some(316206159));

        Ok(())
    }

    // Verifies that loading a checkpoint fails when the chain state has not been initialized.
    #[test]
    fn loading_checkpoint_for_unknown_chain_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        let result = load_last_processed_block(&connection, 421614);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that a negative persisted checkpoint is rejected because block numbers are unsigned.
    #[test]
    fn negative_last_processed_block_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        connection.execute(
            "UPDATE executor_state SET last_processed_block = -1 WHERE chain_id = ?1",
            [421614_i64],
        )?;

        let result = load_last_processed_block(&connection, 421614);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that saving a new checkpoint replaces the previous block for the same chain.
    #[test]
    fn saving_last_processed_block_overwrites_existing_checkpoint() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        save_last_processed_block(&connection, 421614, 316206159)?;
        save_last_processed_block(&connection, 421614, 316206200)?;

        let last_processed_block = load_last_processed_block(&connection, 421614)?;

        assert_eq!(last_processed_block, Some(316206200));

        Ok(())
    }

    // Verifies that saving a checkpoint fails when no state row exists for the requested chain.
    #[test]
    fn saving_checkpoint_for_unknown_chain_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        let result = save_last_processed_block(&connection, 421614, 316206159);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that block numbers too large for SQLite `INTEGER` fail instead of being silently
    // narrowed.
    #[test]
    fn oversized_last_processed_block_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;
        initialize_chain_state(&connection, 421614)?;

        let result = save_last_processed_block(&connection, 421614, u64::MAX);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that a newly discovered payment ID is persisted as a candidate.
    #[test]
    fn candidate_is_inserted() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        let payment_id = U256::from(0);
        let expected_payment_id = payment_id.to_string();

        insert_candidate(&connection, payment_id)?;

        let stored_payment_id: String =
            connection.query_row("SELECT payment_id FROM candidate_payments", [], |row| {
                row.get("payment_id")
            })?;

        assert_eq!(stored_payment_id, expected_payment_id);

        Ok(())
    }

    // Verifies that rediscovering the same payment ID does not create a duplicate candidate.
    #[test]
    fn duplicate_candidate_is_ignored() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        insert_candidate(&connection, U256::from(1))?;
        insert_candidate(&connection, U256::from(1))?;

        // `COUNT(*)` returns one result row whose first column contains the total row count.
        let row_count: i64 =
            connection.query_row("SELECT COUNT(*) FROM candidate_payments", [], |row| {
                row.get(0)
            })?;

        assert_eq!(row_count, 1);

        Ok(())
    }

    // Verifies that a full-width `U256` payment ID is stored losslessly as decimal text.
    #[test]
    fn maximum_u256_candidate_is_stored_as_text() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;

        initialize_schema(&connection)?;

        let payment_id = U256::MAX;
        let expected_payment_id = payment_id.to_string();

        insert_candidate(&connection, payment_id)?;

        let stored_payment_id: String =
            connection.query_row("SELECT payment_id FROM candidate_payments", [], |row| {
                row.get("payment_id")
            })?;

        assert_eq!(stored_payment_id, expected_payment_id);

        Ok(())
    }

    // Verifies that loading from an empty candidate table returns an empty collection.
    #[test]
    fn no_candidates_returns_empty_collection() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;
        initialize_schema(&connection)?;

        let candidates = load_candidates(&connection)?;

        assert!(candidates.is_empty());

        Ok(())
    }

    // Verifies that persisted candidate payment IDs are loaded back as `U256` values.
    #[test]
    fn candidates_are_loaded() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;
        initialize_schema(&connection)?;

        let first_payment_id = U256::from(0_u64);
        let second_payment_id = U256::from(1_u64);

        insert_candidate(&connection, first_payment_id)?;
        insert_candidate(&connection, second_payment_id)?;

        let candidates = load_candidates(&connection)?;

        assert_eq!(candidates.len(), 2);
        assert!(candidates.contains(&first_payment_id));
        assert!(candidates.contains(&second_payment_id));

        Ok(())
    }

    // Verifies that invalid persisted payment ID text is rejected when loading candidates.
    #[test]
    fn invalid_candidate_payment_id_returns_error() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;
        initialize_schema(&connection)?;

        connection.execute(
            "INSERT INTO candidate_payments (payment_id)
             VALUES (?1)",
            ["invalid-payment-id"],
        )?;

        let result = load_candidates(&connection);

        assert!(result.is_err());

        Ok(())
    }

    // Verifies that a persisted candidate payment ID can be removed.
    #[test]
    fn candidate_is_removed() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;
        initialize_schema(&connection)?;

        let payment_id = U256::from(0_u64);

        insert_candidate(&connection, payment_id)?;
        remove_candidate(&connection, payment_id)?;

        let candidates = load_candidates(&connection)?;

        assert!(!candidates.contains(&payment_id));

        Ok(())
    }

    // Verifies that removing a candidate that is not persisted succeeds without error.
    #[test]
    fn missing_candidate_is_ignored() -> Result<(), Box<dyn Error>> {
        let connection = Connection::open_in_memory()?;
        initialize_schema(&connection)?;

        let payment_id = U256::from(0_u64);

        remove_candidate(&connection, payment_id)?;

        Ok(())
    }
}
