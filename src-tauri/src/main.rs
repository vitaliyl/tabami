// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod types;
mod demo_database;
mod connection_manager;
mod schema_inspector;
mod query_runner;
mod commands;

use std::sync::Arc;
use connection_manager::ConnectionManager;
use commands::AppState;

fn main() {
    println!("--------------------------------------------------");
    println!("💎 Tabami Database Studio (Rust Native Core v0.1.0)");
    println!("--------------------------------------------------");
    println!("[Tabami Rust Core] Initializing connection manager...");

    let connection_manager = Arc::new(ConnectionManager::new());
    let state = AppState { connection_manager };

    println!("[Tabami Rust Core] Launching Tauri desktop runtime...");

    tauri::Builder::default()
        .manage(state)
        .invoke_handler(tauri::generate_handler![
            commands::get_initial_state,
            commands::get_connections,
            commands::save_connection,
            commands::delete_connection,
            commands::test_connection,
            commands::discover_databases,
            commands::get_schemas,
            commands::get_tables,
            commands::get_table_structure,
            commands::execute_query,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Tabami desktop application");
}
