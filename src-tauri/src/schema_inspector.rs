use sqlx::Row;
use crate::connection_manager::DbPool;
use crate::types::{ColumnInfo, ForeignKeyInfo, IndexInfo, TableItem, TableStructure};

pub struct SchemaInspector;

impl SchemaInspector {
    pub async fn list_schemas(pool: &DbPool) -> Result<Vec<String>, String> {
        match pool {
            DbPool::Sqlite(_) => Ok(vec!["main".to_string()]),
            DbPool::Postgres(pg) => {
                let rows = sqlx::query(
                    r#"
                    SELECT schema_name 
                    FROM information_schema.schemata 
                    WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
                    ORDER BY schema_name
                    "#,
                )
                .fetch_all(pg)
                .await
                .map_err(|e| e.to_string())?;

                let schemas: Vec<String> = rows.into_iter().map(|r| r.get("schema_name")).collect();
                if schemas.is_empty() {
                    Ok(vec!["public".to_string()])
                } else {
                    Ok(schemas)
                }
            }
            DbPool::MySql(my) => {
                let rows = sqlx::query("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')")
                    .fetch_all(my)
                    .await
                    .map_err(|e| e.to_string())?;

                let schemas: Vec<String> = rows.into_iter().map(|r| r.get("SCHEMA_NAME")).collect();
                Ok(schemas)
            }
        }
    }

    pub async fn list_tables(pool: &DbPool, schema: Option<&str>) -> Result<Vec<TableItem>, String> {
        match pool {
            DbPool::Sqlite(sqlite) => {
                let rows = sqlx::query(
                    r#"
                    SELECT name, type 
                    FROM sqlite_master 
                    WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%'
                    ORDER BY name
                    "#,
                )
                .fetch_all(sqlite)
                .await
                .map_err(|e| e.to_string())?;

                let mut tables = Vec::new();
                for r in rows {
                    let name: String = r.get("name");
                    let table_type: String = r.get("type");

                    let count: Option<i64> = if table_type == "table" {
                        let count_sql = format!("SELECT COUNT(*) FROM \"{}\"", name.replace('"', "\"\""));
                        sqlx::query_scalar(&count_sql)
                            .fetch_one(sqlite)
                            .await
                            .ok()
                    } else {
                        None
                    };

                    tables.push(TableItem {
                        name,
                        table_type,
                        schema: Some("main".to_string()),
                        estimated_rows: count,
                    });
                }

                Ok(tables)
            }
            DbPool::Postgres(pg) => {
                let target_schema = schema.unwrap_or("public");
                let rows = sqlx::query(
                    r#"
                    SELECT 
                        table_name,
                        table_type,
                        (
                            SELECT COALESCE(c.reltuples, 0)::bigint
                            FROM pg_class c
                            JOIN pg_namespace n ON n.oid = c.relnamespace
                            WHERE n.nspname = table_schema AND c.relname = table_name
                        ) AS estimated_rows
                    FROM information_schema.tables
                    WHERE table_schema = $1
                    ORDER BY table_name
                    "#,
                )
                .bind(target_schema)
                .fetch_all(pg)
                .await
                .map_err(|e| e.to_string())?;

                let mut tables = Vec::new();
                for r in rows {
                    let name: String = r.get("table_name");
                    let raw_type: String = r.get("table_type");
                    let table_type = if raw_type.contains("VIEW") { "view" } else { "table" }.to_string();
                    let estimated: Option<i64> = r.try_get("estimated_rows").ok();

                    tables.push(TableItem {
                        name,
                        table_type,
                        schema: Some(target_schema.to_string()),
                        estimated_rows: estimated,
                    });
                }

                Ok(tables)
            }
            DbPool::MySql(my) => {
                let rows = sqlx::query(
                    r#"
                    SELECT 
                        TABLE_NAME, 
                        TABLE_TYPE, 
                        TABLE_ROWS 
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_SCHEMA = DATABASE()
                    ORDER BY TABLE_NAME
                    "#,
                )
                .fetch_all(my)
                .await
                .map_err(|e| e.to_string())?;

                let mut tables = Vec::new();
                for r in rows {
                    let name: String = r.get("TABLE_NAME");
                    let raw_type: String = r.get("TABLE_TYPE");
                    let table_type = if raw_type.contains("VIEW") { "view" } else { "table" }.to_string();
                    let rows_count: Option<i64> = r.try_get("TABLE_ROWS").ok();

                    tables.push(TableItem {
                        name,
                        table_type,
                        schema: schema.map(|s| s.to_string()),
                        estimated_rows: rows_count,
                    });
                }

                Ok(tables)
            }
        }
    }

    pub async fn get_table_structure(
        pool: &DbPool,
        table: &str,
        schema: Option<&str>,
    ) -> Result<TableStructure, String> {
        match pool {
            DbPool::Sqlite(sqlite) => {
                let pragma_sql = format!("PRAGMA table_info(\"{}\")", table.replace('"', "\"\""));
                let col_rows = sqlx::query(&pragma_sql)
                    .fetch_all(sqlite)
                    .await
                    .map_err(|e| e.to_string())?;

                let mut columns = Vec::new();
                let mut primary_keys = Vec::new();

                for r in col_rows {
                    let name: String = r.get("name");
                    let db_type: String = r.get("type");
                    let notnull: i32 = r.get("notnull");
                    let dflt_value: Option<String> = r.get("dflt_value");
                    let pk: i32 = r.get("pk");

                    let is_pk = pk > 0;
                    if is_pk {
                        primary_keys.push(name.clone());
                    }

                    let simplified_type = Self::normalize_type(&db_type);

                    columns.push(ColumnInfo {
                        name,
                        col_type: simplified_type,
                        db_type,
                        allow_null: notnull == 0,
                        default: dflt_value,
                        primary_key: is_pk,
                    });
                }

                // Foreign keys
                let fk_sql = format!("PRAGMA foreign_key_list(\"{}\")", table.replace('"', "\"\""));
                let fk_rows = sqlx::query(&fk_sql).fetch_all(sqlite).await.unwrap_or_default();
                let mut foreign_keys = Vec::new();
                for r in fk_rows {
                    let from_col: String = r.get("from");
                    let to_table: String = r.get("table");
                    let to_col: String = r.get("to");
                    let on_delete: Option<String> = r.try_get("on_delete").ok();

                    foreign_keys.push(ForeignKeyInfo {
                        name: format!("fk_{}_{}", table, from_col),
                        columns: vec![from_col],
                        table: to_table,
                        key: vec![to_col],
                        on_delete,
                    });
                }

                // Indexes
                let idx_sql = format!("PRAGMA index_list(\"{}\")", table.replace('"', "\"\""));
                let idx_rows = sqlx::query(&idx_sql).fetch_all(sqlite).await.unwrap_or_default();
                let mut indexes = Vec::new();
                for r in idx_rows {
                    let idx_name: String = r.get("name");
                    let unique: i32 = r.get("unique");

                    let idx_info_sql = format!("PRAGMA index_info(\"{}\")", idx_name.replace('"', "\"\""));
                    let idx_info_rows = sqlx::query(&idx_info_sql).fetch_all(sqlite).await.unwrap_or_default();
                    let idx_cols: Vec<String> = idx_info_rows.into_iter().map(|ir| ir.get("name")).collect();

                    indexes.push(IndexInfo {
                        name: idx_name,
                        columns: idx_cols,
                        unique: unique != 0,
                    });
                }

                let total_rows: i64 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM \"{}\"", table.replace('"', "\"\"")))
                    .fetch_one(sqlite)
                    .await
                    .unwrap_or(0);

                Ok(TableStructure {
                    table_name: table.to_string(),
                    schema: schema.unwrap_or("main").to_string(),
                    columns,
                    primary_keys,
                    foreign_keys,
                    indexes,
                    total_rows,
                })
            }
            DbPool::Postgres(pg) => {
                let target_schema = schema.unwrap_or("public");

                // Columns
                let col_sql = r#"
                    SELECT 
                        column_name,
                        data_type,
                        udt_name,
                        is_nullable,
                        column_default,
                        EXISTS (
                            SELECT 1 
                            FROM information_schema.table_constraints tc
                            JOIN information_schema.key_column_usage kcu 
                                ON tc.constraint_name = kcu.constraint_name 
                                AND tc.table_schema = kcu.table_schema
                            WHERE tc.constraint_type = 'PRIMARY KEY' 
                                AND tc.table_schema = $1 
                                AND tc.table_name = $2 
                                AND kcu.column_name = c.column_name
                        ) AS is_pk
                    FROM information_schema.columns c
                    WHERE table_schema = $1 AND table_name = $2
                    ORDER BY ordinal_position
                "#;

                let col_rows = sqlx::query(col_sql)
                    .bind(target_schema)
                    .bind(table)
                    .fetch_all(pg)
                    .await
                    .map_err(|e| e.to_string())?;

                let mut columns = Vec::new();
                let mut primary_keys = Vec::new();

                for r in col_rows {
                    let name: String = r.get("column_name");
                    let data_type: String = r.get("data_type");
                    let udt_name: String = r.get("udt_name");
                    let is_nullable: String = r.get("is_nullable");
                    let column_default: Option<String> = r.get("column_default");
                    let is_pk: bool = r.get("is_pk");

                    if is_pk {
                        primary_keys.push(name.clone());
                    }

                    let simplified_type = Self::normalize_type(&udt_name);

                    columns.push(ColumnInfo {
                        name,
                        col_type: simplified_type,
                        db_type: data_type,
                        allow_null: is_nullable == "YES",
                        default: column_default,
                        primary_key: is_pk,
                    });
                }

                let total_rows: i64 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM \"{}\".\"{}\"", target_schema.replace('"', "\"\""), table.replace('"', "\"\"")))
                    .fetch_one(pg)
                    .await
                    .unwrap_or(0);

                Ok(TableStructure {
                    table_name: table.to_string(),
                    schema: target_schema.to_string(),
                    columns,
                    primary_keys,
                    foreign_keys: Vec::new(),
                    indexes: Vec::new(),
                    total_rows,
                })
            }
            DbPool::MySql(my) => {
                let col_rows = sqlx::query(
                    r#"
                    SELECT 
                        COLUMN_NAME, 
                        DATA_TYPE, 
                        COLUMN_TYPE, 
                        IS_NULLABLE, 
                        COLUMN_DEFAULT, 
                        COLUMN_KEY 
                    FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
                    ORDER BY ORDINAL_POSITION
                    "#,
                )
                .bind(table)
                .fetch_all(my)
                .await
                .map_err(|e| e.to_string())?;

                let mut columns = Vec::new();
                let mut primary_keys = Vec::new();

                for r in col_rows {
                    let name: String = r.get("COLUMN_NAME");
                    let data_type: String = r.get("DATA_TYPE");
                    let col_type: String = r.get("COLUMN_TYPE");
                    let is_nullable: String = r.get("IS_NULLABLE");
                    let dflt: Option<String> = r.get("COLUMN_DEFAULT");
                    let key: String = r.get("COLUMN_KEY");

                    let is_pk = key == "PRI";
                    if is_pk {
                        primary_keys.push(name.clone());
                    }

                    let simplified_type = Self::normalize_type(&data_type);

                    columns.push(ColumnInfo {
                        name,
                        col_type: simplified_type,
                        db_type: col_type,
                        allow_null: is_nullable == "YES",
                        default: dflt,
                        primary_key: is_pk,
                    });
                }

                let total_rows: i64 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM `{}`", table.replace('`', "``")))
                    .fetch_one(my)
                    .await
                    .unwrap_or(0);

                Ok(TableStructure {
                    table_name: table.to_string(),
                    schema: schema.unwrap_or("").to_string(),
                    columns,
                    primary_keys,
                    foreign_keys: Vec::new(),
                    indexes: Vec::new(),
                    total_rows,
                })
            }
        }
    }

    fn normalize_type(db_type: &str) -> String {
        let t = db_type.to_lowercase();
        if t.contains("int") {
            "integer".to_string()
        } else if t.contains("char") || t.contains("text") || t.contains("clob") {
            "string".to_string()
        } else if t.contains("float") || t.contains("double") || t.contains("decimal") || t.contains("numeric") || t.contains("real") {
            "float".to_string()
        } else if t.contains("bool") {
            "boolean".to_string()
        } else if t.contains("date") || t.contains("time") {
            "datetime".to_string()
        } else if t.contains("json") {
            "json".to_string()
        } else if t.contains("blob") || t.contains("bytea") {
            "binary".to_string()
        } else {
            "string".to_string()
        }
    }
}
