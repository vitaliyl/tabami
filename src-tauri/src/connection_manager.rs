use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use sqlx::{sqlite::SqlitePool, postgres::PgPool, mysql::MySqlPool};
use uuid::Uuid;

use crate::demo_database::{ensure_demo_database, get_demo_db_path, get_tabami_data_dir};
use crate::types::{ConnectionConfig, TestConnectionResult};

#[derive(Clone)]
pub enum DbPool {
    Sqlite(SqlitePool),
    Postgres(PgPool),
    MySql(MySqlPool),
}

fn build_postgres_url(config: &ConnectionConfig) -> String {
    let host = config.host.as_deref().filter(|s| !s.is_empty()).unwrap_or("localhost");
    let port = config.port.unwrap_or(5432);
    let user = config.user.as_deref().filter(|s| !s.is_empty()).unwrap_or("postgres");
    let password = config.password.as_deref().unwrap_or("");
    let database = config.database.as_deref().filter(|s| !s.is_empty()).unwrap_or("postgres");
    let ssl_mode = if config.ssl.unwrap_or(false) { "require" } else { "prefer" };

    if password.is_empty() {
        format!("postgres://{}@{}:{}/{}?sslmode={}", user, host, port, database, ssl_mode)
    } else {
        format!("postgres://{}:{}@{}:{}/{}?sslmode={}", user, password, host, port, database, ssl_mode)
    }
}

fn build_mysql_url(config: &ConnectionConfig) -> String {
    let host = config.host.as_deref().filter(|s| !s.is_empty()).unwrap_or("localhost");
    let port = config.port.unwrap_or(3306);
    let user = config.user.as_deref().filter(|s| !s.is_empty()).unwrap_or("root");
    let password = config.password.as_deref().unwrap_or("");
    let database = config.database.as_deref().unwrap_or("");

    if password.is_empty() {
        format!("mysql://{}@{}:{}/{}", user, host, port, database)
    } else {
        format!("mysql://{}:{}@{}:{}/{}", user, password, host, port, database)
    }
}

pub struct ConnectionManager {
    pools: RwLock<HashMap<String, DbPool>>,
    saved_connections_file: PathBuf,
}

impl ConnectionManager {
    pub fn new() -> Self {
        let dir = get_tabami_data_dir();
        let _ = std::fs::create_dir_all(&dir);
        let saved_connections_file = dir.join("saved_connections.json");

        Self {
            pools: RwLock::new(HashMap::new()),
            saved_connections_file,
        }
    }

    pub async fn list_connections(&self) -> Vec<ConnectionConfig> {
        let _ = ensure_demo_database().await;

        let demo_path = get_demo_db_path();
        let demo_config = ConnectionConfig {
            id: "demo".to_string(),
            name: "Demo Database".to_string(),
            adapter: "sqlite".to_string(),
            host: None,
            port: None,
            database: Some("demo.sqlite3".to_string()),
            user: None,
            password: None,
            file_path: demo_path.to_str().map(|s| s.to_string()),
            ssl: None,
            is_demo: true,
        };

        let mut connections = vec![demo_config];

        if self.saved_connections_file.exists() {
            if let Ok(content) = tokio::fs::read_to_string(&self.saved_connections_file).await {
                if let Ok(saved) = serde_json::from_str::<Vec<ConnectionConfig>>(&content) {
                    for c in saved {
                        if c.id != "demo" {
                            connections.push(c);
                        }
                    }
                }
            }
        }

        connections
    }

    pub async fn get_connection(&self, id: &str) -> Option<ConnectionConfig> {
        let all = self.list_connections().await;
        all.into_iter().find(|c| c.id == id)
    }

    pub async fn add_connection(&self, mut config: ConnectionConfig) -> Result<ConnectionConfig, String> {
        if config.id.is_empty() {
            config.id = Uuid::new_v4().to_string();
        }

        let mut all = self.list_connections().await;
        // Don't duplicate
        all.retain(|c| c.id != config.id && !c.is_demo);
        all.push(config.clone());

        // Save only non-demo
        let to_save: Vec<ConnectionConfig> = all.into_iter().filter(|c| !c.is_demo).collect();
        let json = serde_json::to_string_pretty(&to_save).map_err(|e| e.to_string())?;
        tokio::fs::write(&self.saved_connections_file, json).await.map_err(|e| e.to_string())?;

        Ok(config)
    }

    pub async fn delete_connection(&self, id: &str) -> Result<(), String> {
        if id == "demo" {
            return Err("Cannot delete demo database".to_string());
        }

        let mut all = self.list_connections().await;
        all.retain(|c| c.id != id && !c.is_demo);

        let json = serde_json::to_string_pretty(&all).map_err(|e| e.to_string())?;
        tokio::fs::write(&self.saved_connections_file, json).await.map_err(|e| e.to_string())?;

        let mut pools = self.pools.write().await;
        pools.remove(id);

        Ok(())
    }

    pub async fn get_or_create_pool(&self, config: &ConnectionConfig) -> Result<DbPool, String> {
        let mut pools = self.pools.write().await;
        if let Some(pool) = pools.get(&config.id) {
            return Ok(pool.clone());
        }

        let pool = match config.adapter.to_lowercase().as_str() {
            "sqlite" => {
                let path_str = config
                    .file_path
                    .as_deref()
                    .or(config.database.as_deref())
                    .ok_or_else(|| "SQLite file path is required".to_string())?;

                let pool = SqlitePool::connect(&format!("sqlite:{}?mode=rwc", path_str))
                    .await
                    .map_err(|e| format!("SQLite connection failed: {}", e))?;
                DbPool::Sqlite(pool)
            }
            "postgres" | "postgresql" => {
                let url = build_postgres_url(config);
                let pool = PgPool::connect(&url)
                    .await
                    .map_err(|e| format!("PostgreSQL connection failed: {}", e))?;
                DbPool::Postgres(pool)
            }
            "mysql" => {
                let url = build_mysql_url(config);
                let pool = MySqlPool::connect(&url)
                    .await
                    .map_err(|e| format!("MySQL connection failed: {}", e))?;
                DbPool::MySql(pool)
            }
            other => return Err(format!("Unsupported database adapter: {}", other)),
        };

        pools.insert(config.id.clone(), pool.clone());
        Ok(pool)
    }

    pub async fn test_connection(&self, config: &ConnectionConfig) -> TestConnectionResult {
        match config.adapter.to_lowercase().as_str() {
            "sqlite" => {
                let path_str = config
                    .file_path
                    .as_deref()
                    .or(config.database.as_deref())
                    .unwrap_or("");

                match SqlitePool::connect(&format!("sqlite:{}?mode=rwc", path_str)).await {
                    Ok(pool) => {
                        let version: (String,) = sqlx::query_as("SELECT sqlite_version()")
                            .fetch_one(&pool)
                            .await
                            .unwrap_or_else(|_| ("unknown".to_string(),));

                        TestConnectionResult {
                            success: true,
                            message: Some(format!("Successfully connected to SQLite {}", version.0)),
                            error: None,
                            server_version: Some(version.0),
                            database: Some(path_str.to_string()),
                            adapter: Some("sqlite".to_string()),
                        }
                    }
                    Err(e) => TestConnectionResult {
                        success: false,
                        message: Some(format!("SQLite connection error: {}", e)),
                        error: Some(e.to_string()),
                        server_version: None,
                        database: None,
                        adapter: Some("sqlite".to_string()),
                    },
                }
            }
            "postgres" | "postgresql" => {
                let url = build_postgres_url(config);
                let db_name = config.database.as_deref().filter(|s| !s.is_empty()).unwrap_or("postgres");
                match PgPool::connect(&url).await {
                    Ok(pool) => {
                        let version: (String,) = sqlx::query_as("SELECT version()")
                            .fetch_one(&pool)
                            .await
                            .unwrap_or_else(|_| ("PostgreSQL".to_string(),));

                        TestConnectionResult {
                            success: true,
                            message: Some(format!("Successfully connected to PostgreSQL ({})", db_name)),
                            error: None,
                            server_version: Some(version.0),
                            database: Some(db_name.to_string()),
                            adapter: Some("postgres".to_string()),
                        }
                    }
                    Err(e) => {
                        eprintln!("[Tabami Rust Core] PostgreSQL connection test error: {}", e);
                        TestConnectionResult {
                            success: false,
                            message: Some(format!("Connection failed: {}", e)),
                            error: Some(e.to_string()),
                            server_version: None,
                            database: Some(db_name.to_string()),
                            adapter: Some("postgres".to_string()),
                        }
                    }
                }
            }
            "mysql" => {
                let url = build_mysql_url(config);
                let db_name = config.database.as_deref().unwrap_or("");
                match MySqlPool::connect(&url).await {
                    Ok(pool) => {
                        let version: (String,) = sqlx::query_as("SELECT VERSION()")
                            .fetch_one(&pool)
                            .await
                            .unwrap_or_else(|_| ("MySQL".to_string(),));

                        TestConnectionResult {
                            success: true,
                            message: Some(format!("Successfully connected to MySQL ({})", db_name)),
                            error: None,
                            server_version: Some(version.0),
                            database: Some(db_name.to_string()),
                            adapter: Some("mysql".to_string()),
                        }
                    }
                    Err(e) => {
                        eprintln!("[Tabami Rust Core] MySQL connection test error: {}", e);
                        TestConnectionResult {
                            success: false,
                            message: Some(format!("Connection failed: {}", e)),
                            error: Some(e.to_string()),
                            server_version: None,
                            database: Some(db_name.to_string()),
                            adapter: Some("mysql".to_string()),
                        }
                    }
                }
            }
            other => TestConnectionResult {
                success: false,
                message: Some(format!("Unsupported database adapter: {}", other)),
                error: Some(format!("Unsupported database adapter: {}", other)),
                server_version: None,
                database: None,
                adapter: Some(other.to_string()),
            },
        }
    }

    pub async fn discover_databases(&self, config: &ConnectionConfig) -> Result<Vec<String>, String> {
        match config.adapter.to_lowercase().as_str() {
            "postgres" | "postgresql" => {
                let url = build_postgres_url(config);
                let pool = PgPool::connect(&url).await.map_err(|e| format!("PostgreSQL connection failed: {}", e))?;
                let rows: Vec<(String,)> = sqlx::query_as(
                    "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true ORDER BY datname"
                )
                .fetch_all(&pool)
                .await
                .map_err(|e| format!("Failed to list databases: {}", e))?;

                Ok(rows.into_iter().map(|r| r.0).collect())
            }
            "mysql" => {
                let url = build_mysql_url(config);
                let pool = MySqlPool::connect(&url).await.map_err(|e| format!("MySQL connection failed: {}", e))?;
                let rows: Vec<(String,)> = sqlx::query_as("SHOW DATABASES")
                    .fetch_all(&pool)
                    .await
                    .map_err(|e| format!("Failed to list databases: {}", e))?;

                let system_dbs = ["information_schema", "performance_schema", "mysql", "sys"];
                let dbs: Vec<String> = rows
                    .into_iter()
                    .map(|r| r.0)
                    .filter(|name| !system_dbs.contains(&name.to_lowercase().as_str()))
                    .collect();

                Ok(dbs)
            }
            "sqlite" => {
                let dir = get_tabami_data_dir();
                let mut dbs = vec!["~/.tabami/demo.sqlite3".to_string()];
                if let Ok(mut entries) = tokio::fs::read_dir(&dir).await {
                    while let Ok(Some(entry)) = entries.next_entry().await {
                        let path = entry.path();
                        if let Some(ext) = path.extension() {
                            if (ext == "sqlite" || ext == "sqlite3" || ext == "db") && !dbs.contains(&path.to_string_lossy().to_string()) {
                                dbs.push(path.to_string_lossy().to_string());
                            }
                        }
                    }
                }
                Ok(dbs)
            }
            other => Err(format!("Unsupported adapter for discovery: {}", other)),
        }
    }
}
