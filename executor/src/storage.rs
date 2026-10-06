use rusqlite::{Connection, OptionalExtension};
use std::{error::Error, path::Path};

// Opens the executor's SQLite database, creating the database file if it does not exist.
pub(crate) fn open_database(database_path: &Path) -> Result<Connection, Box<dyn Error>> {
    let connection = Connection::open(database_path)?;

    Ok(connection)
}

// Creates the executor's required database tables if they do not already exist.
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

// Initializes the persisted chain ID or validates it against the configured chain.
pub(crate) fn initialize_chain_state(
    connection: &Connection,
    configured_chain_id: u64,
) -> Result<(), Box<dyn Error>> {
    // SQLite INTEGER is signed 64-bit so use a checked conversion so oversized u64 chain IDs fail instead of narrowing silently.
    let configured_chain_id = i64::try_from(configured_chain_id)?;

    // `query_row` passes the returned SQLite row to the closure which extracts `chain_id` and
    // decodes it as an i64. optional() treats a missing row as None instead of an error so a new
    // database can initialize its chain state.
    let stored_chain_id = connection
        .query_row("SELECT chain_id FROM executor_state", [], |row| {
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
