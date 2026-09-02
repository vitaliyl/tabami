use std::sync::Arc;
use tauri::State;
use crate::connection_manager::ConnectionManager;
use crate::schema_inspector::SchemaInspector;
use crate::query_runner::QueryRunner;
use crate::types::{ConnectionConfig, QueryResult, TableItem, TableStructure, TestConnectionResult};

pub struct AppState {
    pub connection_manager: Arc<ConnectionManager>,
}

#[derive(serde::Serialize)]
pub struct InitialStateResponse {
    pub connections: Vec<ConnectionConfig>,
    pub active_connection: Option<ConnectionConfig>,
    pub schemas: Vec<String>,
    pub selected_schema: String,
    pub tables: Vec<TableItem>,
}

#[tauri::command]
pub async fn get_initial_state(
    state: State<'_, AppState>,
    connection_id: Option<String>,
    schema: Option<String>,
) -> Result<InitialStateResponse, String> {
    println!("[Tabami Rust Core] -> get_initial_state (conn: {:?}, schema: {:?})", connection_id, schema);
    let connections = state.connection_manager.list_connections().await;
    let active_conn = if let Some(id) = connection_id {
        connections.iter().find(|c| c.id == id).cloned()
    } else {
        connections.first().cloned()
    };

    if let Some(conn) = &active_conn {
        println!("[Tabami Rust Core] Active connection: '{}' ({})", conn.name, conn.adapter);
        match state.connection_manager.get_or_create_pool(conn).await {
            Ok(pool) => {
                let schemas = SchemaInspector::list_schemas(&pool).await.unwrap_or_else(|_| vec!["main".to_string()]);
                let selected_schema = schema.unwrap_or_else(|| schemas.first().cloned().unwrap_or_else(|| "main".to_string()));
                let tables = SchemaInspector::list_tables(&pool, Some(&selected_schema)).await.unwrap_or_default();
                println!("[Tabami Rust Core] Loaded {} tables for schema '{}'", tables.len(), selected_schema);

                Ok(InitialStateResponse {
                    connections,
                    active_connection: Some(conn.clone()),
                    schemas,
                    selected_schema,
                    tables,
                })
            }
            Err(e) => {
                eprintln!("[Tabami Rust Core] Error connecting to pool: {}", e);
                // Return connections so UI renders even if one DB connection fails
                Ok(InitialStateResponse {
                    connections,
                    active_connection: Some(conn.clone()),
                    schemas: vec!["main".to_string()],
                    selected_schema: "main".to_string(),
                    tables: Vec::new(),
                })
            }
        }
    } else {
        println!("[Tabami Rust Core] No active connection found, returning empty state");
        Ok(InitialStateResponse {
            connections: Vec::new(),
            active_connection: None,
            schemas: Vec::new(),
            selected_schema: "main".to_string(),
            tables: Vec::new(),
        })
    }
}

#[tauri::command]
pub async fn get_connections(state: State<'_, AppState>) -> Result<Vec<ConnectionConfig>, String> {
    println!("[Tabami Rust Core] -> get_connections");
    Ok(state.connection_manager.list_connections().await)
}

#[tauri::command]
pub async fn save_connection(
    state: State<'_, AppState>,
    config: serde_json::Value,
) -> Result<ConnectionConfig, String> {
    println!("[Tabami Rust Core] -> save_connection payload: {}", config);
    let cfg: ConnectionConfig = serde_json::from_value(config).map_err(|e| format!("Invalid connection payload: {}", e))?;
    state.connection_manager.add_connection(cfg).await
}

#[tauri::command]
pub async fn delete_connection(
    state: State<'_, AppState>,
    id: String,
) -> Result<(), String> {
    println!("[Tabami Rust Core] -> delete_connection: '{}'", id);
    state.connection_manager.delete_connection(&id).await
}

#[tauri::command]
pub async fn test_connection(
    state: State<'_, AppState>,
    config: serde_json::Value,
) -> Result<TestConnectionResult, String> {
    println!("[Tabami Rust Core] -> test_connection raw json: {}", config);
    let cfg: ConnectionConfig = match serde_json::from_value(config.clone()) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("[Tabami Rust Core] Failed to deserialize ConnectionConfig: {}", e);
            return Ok(TestConnectionResult {
                success: false,
                message: Some(format!("Invalid connection fields: {}", e)),
                error: Some(e.to_string()),
                server_version: None,
                database: None,
                adapter: None,
            });
        }
    };

    println!("[Tabami Rust Core] Testing connection for '{}' (adapter: {})", cfg.name, cfg.adapter);
    let res = state.connection_manager.test_connection(&cfg).await;
    println!("[Tabami Rust Core] Test result: success={}, msg={:?}, err={:?}", res.success, res.message, res.error);
    Ok(res)
}

#[tauri::command]
pub async fn discover_databases(
    state: State<'_, AppState>,
    config: serde_json::Value,
) -> Result<Vec<String>, String> {
    println!("[Tabami Rust Core] -> discover_databases: {}", config);
    let cfg: ConnectionConfig = serde_json::from_value(config).map_err(|e| format!("Invalid config: {}", e))?;
    state.connection_manager.discover_databases(&cfg).await
}

#[tauri::command]
pub async fn get_schemas(
    state: State<'_, AppState>,
    connection_id: String,
) -> Result<Vec<String>, String> {
    println!("[Tabami Rust Core] -> get_schemas for conn: {}", connection_id);
    let conn = state.connection_manager.get_connection(&connection_id).await.ok_or("Connection not found")?;
    let pool = state.connection_manager.get_or_create_pool(&conn).await?;
    SchemaInspector::list_schemas(&pool).await
}

#[tauri::command]
pub async fn get_tables(
    state: State<'_, AppState>,
    connection_id: String,
    schema: Option<String>,
) -> Result<Vec<TableItem>, String> {
    println!("[Tabami Rust Core] -> get_tables for conn: {}, schema: {:?}", connection_id, schema);
    let conn = state.connection_manager.get_connection(&connection_id).await.ok_or("Connection not found")?;
    let pool = state.connection_manager.get_or_create_pool(&conn).await?;
    SchemaInspector::list_tables(&pool, schema.as_deref()).await
}

#[tauri::command]
pub async fn get_table_structure(
    state: State<'_, AppState>,
    connection_id: String,
    table: String,
    schema: Option<String>,
) -> Result<TableStructure, String> {
    println!("[Tabami Rust Core] -> get_table_structure for table '{}'", table);
    let conn = state.connection_manager.get_connection(&connection_id).await.ok_or("Connection not found")?;
    let pool = state.connection_manager.get_or_create_pool(&conn).await?;
    SchemaInspector::get_table_structure(&pool, &table, schema.as_deref()).await
}

#[tauri::command]
pub async fn execute_query(
    state: State<'_, AppState>,
    connection_id: Option<String>,
    sql: String,
    limit: Option<usize>,
) -> Result<QueryResult, String> {
    println!("[Tabami Rust Core] -> execute_query: {}", sql.lines().next().unwrap_or(""));
    let target_conn = if let Some(id) = connection_id {
        state.connection_manager.get_connection(&id).await
    } else {
        let all = state.connection_manager.list_connections().await;
        all.into_iter().next()
    };

    let conn = match target_conn {
        Some(c) => c,
        None => {
            return Ok(QueryResult {
                success: false,
                is_select: None,
                columns: None,
                rows: None,
                row_count: None,
                rows_affected: None,
                duration_ms: None,
                error: Some("No active database connection available".to_string()),
                sql: Some(sql),
            });
        }
    };

    let pool = match state.connection_manager.get_or_create_pool(&conn).await {
        Ok(p) => p,
        Err(e) => {
            return Ok(QueryResult {
                success: false,
                is_select: None,
                columns: None,
                rows: None,
                row_count: None,
                rows_affected: None,
                duration_ms: None,
                error: Some(format!("Database connection failed: {}", e)),
                sql: Some(sql),
            });
        }
    };

    let res = QueryRunner::execute(&pool, &sql, limit).await;
    println!("[Tabami Rust Core] Query executed: success={}, rows={:?}", res.success, res.row_count);
    Ok(res)
}
