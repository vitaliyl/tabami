use std::time::Instant;
use serde_json::{Map, Value};
use sqlx::{Column, Row};
use crate::connection_manager::DbPool;
use crate::types::QueryResult;

pub struct QueryRunner;

impl QueryRunner {
    pub async fn execute(pool: &DbPool, sql: &str, _limit: Option<usize>) -> QueryResult {
        let trimmed = sql.trim();
        let is_select = trimmed.to_uppercase().starts_with("SELECT")
            || trimmed.to_uppercase().starts_with("WITH")
            || trimmed.to_uppercase().starts_with("PRAGMA")
            || trimmed.to_uppercase().starts_with("SHOW")
            || trimmed.to_uppercase().starts_with("DESCRIBE")
            || trimmed.to_uppercase().starts_with("EXPLAIN");

        let start = Instant::now();

        match pool {
            DbPool::Sqlite(sqlite) => {
                if is_select {
                    match sqlx::query(trimmed).fetch_all(sqlite).await {
                        Ok(rows) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            let columns: Vec<String> = if let Some(first) = rows.first() {
                                first.columns().iter().map(|c| c.name().to_string()).collect()
                            } else {
                                Vec::new()
                            };

                            let mut json_rows = Vec::new();
                            for r in rows {
                                let mut map = Map::new();
                                for (i, col) in r.columns().iter().enumerate() {
                                    let col_name = col.name().to_string();
                                    let val: Value = Self::extract_sqlite_val(&r, i);
                                    map.insert(col_name, val);
                                }
                                json_rows.push(Value::Object(map));
                            }

                            let row_count = json_rows.len();
                            QueryResult {
                                success: true,
                                is_select: Some(true),
                                columns: Some(columns),
                                rows: Some(json_rows),
                                row_count: Some(row_count),
                                rows_affected: None,
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(true),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                } else {
                    match sqlx::query(trimmed).execute(sqlite).await {
                        Ok(res) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            QueryResult {
                                success: true,
                                is_select: Some(false),
                                columns: Some(Vec::new()),
                                rows: Some(Vec::new()),
                                row_count: Some(0),
                                rows_affected: Some(res.rows_affected()),
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(false),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                }
            }
            DbPool::Postgres(pg) => {
                if is_select {
                    match sqlx::query(trimmed).fetch_all(pg).await {
                        Ok(rows) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            let columns: Vec<String> = if let Some(first) = rows.first() {
                                first.columns().iter().map(|c| c.name().to_string()).collect()
                            } else {
                                Vec::new()
                            };

                            let mut json_rows = Vec::new();
                            for r in rows {
                                let mut map = Map::new();
                                for (i, col) in r.columns().iter().enumerate() {
                                    let col_name = col.name().to_string();
                                    let val: Value = Self::extract_pg_val(&r, i);
                                    map.insert(col_name, val);
                                }
                                json_rows.push(Value::Object(map));
                            }

                            let row_count = json_rows.len();
                            QueryResult {
                                success: true,
                                is_select: Some(true),
                                columns: Some(columns),
                                rows: Some(json_rows),
                                row_count: Some(row_count),
                                rows_affected: None,
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(true),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                } else {
                    match sqlx::query(trimmed).execute(pg).await {
                        Ok(res) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            QueryResult {
                                success: true,
                                is_select: Some(false),
                                columns: Some(Vec::new()),
                                rows: Some(Vec::new()),
                                row_count: Some(0),
                                rows_affected: Some(res.rows_affected()),
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(false),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                }
            }
            DbPool::MySql(my) => {
                if is_select {
                    match sqlx::query(trimmed).fetch_all(my).await {
                        Ok(rows) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            let columns: Vec<String> = if let Some(first) = rows.first() {
                                first.columns().iter().map(|c| c.name().to_string()).collect()
                            } else {
                                Vec::new()
                            };

                            let mut json_rows = Vec::new();
                            for r in rows {
                                let mut map = Map::new();
                                for (i, col) in r.columns().iter().enumerate() {
                                    let col_name = col.name().to_string();
                                    let val: Value = Self::extract_mysql_val(&r, i);
                                    map.insert(col_name, val);
                                }
                                json_rows.push(Value::Object(map));
                            }

                            let row_count = json_rows.len();
                            QueryResult {
                                success: true,
                                is_select: Some(true),
                                columns: Some(columns),
                                rows: Some(json_rows),
                                row_count: Some(row_count),
                                rows_affected: None,
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(true),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                } else {
                    match sqlx::query(trimmed).execute(my).await {
                        Ok(res) => {
                            let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
                            QueryResult {
                                success: true,
                                is_select: Some(false),
                                columns: Some(Vec::new()),
                                rows: Some(Vec::new()),
                                row_count: Some(0),
                                rows_affected: Some(res.rows_affected()),
                                duration_ms: Some((duration_ms * 100.0).round() / 100.0),
                                error: None,
                                sql: Some(sql.to_string()),
                            }
                        }
                        Err(e) => QueryResult {
                            success: false,
                            is_select: Some(false),
                            columns: None,
                            rows: None,
                            row_count: None,
                            rows_affected: None,
                            duration_ms: Some(start.elapsed().as_secs_f64() * 1000.0),
                            error: Some(e.to_string()),
                            sql: Some(sql.to_string()),
                        },
                    }
                }
            }
        }
    }

    fn extract_sqlite_val(row: &sqlx::sqlite::SqliteRow, index: usize) -> Value {
        if let Ok(val) = row.try_get::<i64, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<f64, _>(index) {
            return serde_json::Number::from_f64(val)
                .map(Value::Number)
                .unwrap_or(Value::Null);
        }
        if let Ok(val) = row.try_get::<bool, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<String, _>(index) {
            if val.starts_with('{') || val.starts_with('[') {
                if let Ok(parsed) = serde_json::from_str::<Value>(&val) {
                    return parsed;
                }
            }
            return Value::from(val);
        }
        Value::Null
    }

    fn extract_pg_val(row: &sqlx::postgres::PgRow, index: usize) -> Value {
        if let Ok(val) = row.try_get::<i64, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<i32, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<f64, _>(index) {
            return serde_json::Number::from_f64(val)
                .map(Value::Number)
                .unwrap_or(Value::Null);
        }
        if let Ok(val) = row.try_get::<bool, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<serde_json::Value, _>(index) {
            return val;
        }
        if let Ok(val) = row.try_get::<String, _>(index) {
            return Value::from(val);
        }
        Value::Null
    }

    fn extract_mysql_val(row: &sqlx::mysql::MySqlRow, index: usize) -> Value {
        if let Ok(val) = row.try_get::<i64, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<i32, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<f64, _>(index) {
            return serde_json::Number::from_f64(val)
                .map(Value::Number)
                .unwrap_or(Value::Null);
        }
        if let Ok(val) = row.try_get::<bool, _>(index) {
            return Value::from(val);
        }
        if let Ok(val) = row.try_get::<serde_json::Value, _>(index) {
            return val;
        }
        if let Ok(val) = row.try_get::<String, _>(index) {
            return Value::from(val);
        }
        Value::Null
    }
}
