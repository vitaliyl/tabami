use std::path::PathBuf;
use sqlx::sqlite::SqlitePool;

pub fn get_tabami_data_dir() -> PathBuf {
    let base = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    base.join(".tabami")
}

pub fn get_demo_db_path() -> PathBuf {
    get_tabami_data_dir().join("demo.sqlite3")
}

pub async fn ensure_demo_database() -> Result<PathBuf, String> {
    let dir = get_tabami_data_dir();
    if !dir.exists() {
        std::fs::create_dir_all(&dir).map_err(|e| format!("Failed to create directory {:?}: {}", dir, e))?;
    }

    let db_path = get_demo_db_path();
    let db_path_str = db_path.to_str().ok_or("Invalid DB path")?;
    let pool = SqlitePool::connect(&format!("sqlite:{}?mode=rwc", db_path_str))
        .await
        .map_err(|e| format!("Failed to connect to demo SQLite db: {}", e))?;

    // Create tables and seed data if not existing
    let schema_sql = r#"
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            role TEXT NOT NULL DEFAULT 'member',
            status TEXT NOT NULL DEFAULT 'active',
            metadata JSON,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            plan TEXT NOT NULL DEFAULT 'starter',
            balance_cents INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS sports_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            location TEXT NOT NULL,
            max_participants INTEGER NOT NULL DEFAULT 10,
            starts_at DATETIME NOT NULL,
            status TEXT NOT NULL DEFAULT 'scheduled',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS event_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL REFERENCES sports_events(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            rsvp_status TEXT NOT NULL DEFAULT 'attending',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS ledger_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            currency TEXT NOT NULL DEFAULT 'USD',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS ledger_charges (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
            amount_cents INTEGER NOT NULL,
            description TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            actor_id INTEGER,
            payload JSON,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
        CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
        CREATE INDEX IF NOT EXISTS idx_event_members_event_id ON event_members(event_id);
        CREATE INDEX IF NOT EXISTS idx_ledger_charges_account_id ON ledger_charges(account_id);
    "#;

    sqlx::query(schema_sql)
        .execute(&pool)
        .await
        .map_err(|e| format!("Failed to create demo schema: {}", e))?;

    // Seed users if empty
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap_or((0,));

    if count.0 == 0 {
        let seed_sql = r#"
            INSERT INTO users (name, email, role, status, metadata) VALUES
            ('Aoi Takahashi', 'aoi@tabami.dev', 'admin', 'active', '{"theme":"matcha","tier":"enterprise","logins":42}'),
            ('Ren Sato', 'ren@tabami.dev', 'developer', 'active', '{"theme":"sumi","tier":"pro","logins":18}'),
            ('Hana Suzuki', 'hana@tabami.dev', 'member', 'active', '{"theme":"washi","tier":"starter","logins":5}'),
            ('Kenji Tanaka', 'kenji@tabami.dev', 'member', 'pending', '{"theme":"sumi","tier":"starter","logins":1}');

            INSERT INTO accounts (user_id, plan, balance_cents) VALUES
            (1, 'enterprise', 249000),
            (2, 'pro', 4900),
            (3, 'starter', 0),
            (4, 'starter', 0);

            INSERT INTO sports_events (title, location, max_participants, starts_at, status) VALUES
            ('Saturday Tennis Tournament', 'Tokyo Sports Arena', 16, datetime('now', '+2 days'), 'scheduled'),
            ('Weekly Bouldering Session', 'Shibuya Climbing Gym', 8, datetime('now', '+4 days'), 'scheduled'),
            ('Morning Badminton Club', 'Shinjuku Center Court', 12, datetime('now', '+7 days'), 'scheduled');

            INSERT INTO event_members (event_id, user_id, rsvp_status) VALUES
            (1, 1, 'attending'),
            (1, 2, 'attending'),
            (2, 2, 'attending'),
            (2, 3, 'attending'),
            (3, 1, 'attending'),
            (3, 3, 'waitlist');

            INSERT INTO ledger_accounts (code, name, currency) VALUES
            ('1010', 'Operating Cash Account', 'USD'),
            ('2010', 'Accounts Payable', 'USD'),
            ('4010', 'Subscription Revenue', 'USD');

            INSERT INTO ledger_charges (account_id, amount_cents, description) VALUES
            (1, 249000, 'Enterprise Annual License Renewal'),
            (2, 4900, 'Monthly Developer Pro Subscription');

            INSERT INTO audit_logs (action, actor_id, payload) VALUES
            ('user.login', 1, '{"ip":"127.0.0.1","browser":"Tauri/2.0"}'),
            ('connection.created', 1, '{"adapter":"sqlite","database":"demo.sqlite3"}'),
            ('query.executed', 2, '{"query":"SELECT * FROM sports_events LIMIT 10;"}');
        "#;

        sqlx::query(seed_sql)
            .execute(&pool)
            .await
            .map_err(|e| format!("Failed to seed demo data: {}", e))?;
    }

    Ok(db_path)
}
