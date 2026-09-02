import type { TableItem } from './domainClassifier';

export function isTauri(): boolean {
  return (
    typeof window !== 'undefined' &&
    ('__TAURI_INTERNALS__' in window || '__TAURI__' in window)
  );
}

async function invokeTauri<T>(cmd: string, args?: Record<string, any>): Promise<T> {
  const tauriInternals = (window as any).__TAURI_INTERNALS__;
  const invokeFn = typeof tauriInternals?.invoke === 'function'
    ? tauriInternals.invoke.bind(tauriInternals)
    : typeof (window as any).__TAURI__?.invoke === 'function'
      ? (window as any).__TAURI__.invoke.bind((window as any).__TAURI__)
      : null;

  if (!invokeFn) {
    throw new Error(`Tauri IPC not available in this environment for command: ${cmd}`);
  }

  try {
    console.log(`[Tauri IPC ->] ${cmd}`, args);
    const result = await invokeFn(cmd, args);
    console.log(`[Tauri IPC <-] ${cmd}`, result);
    return result as T;
  } catch (err) {
    console.error(`[Tauri IPC ERROR] ${cmd}:`, err);
    throw err;
  }
}

export interface ConnectionConfig {
  id: string;
  name: string;
  adapter: string;
  is_demo?: boolean;
  database?: string;
  host?: string;
  port?: number;
  user?: string;
  username?: string;
  password?: string;
  file_path?: string;
  ssl?: boolean;
}

export { TableItem };

export interface TableStructure {
  table_name: string;
  schema: string;
  columns: any[];
  primary_keys: string[];
  foreign_keys: any[];
  indexes: any[];
  total_rows: number;
}

export interface QueryResult {
  success: boolean;
  is_select?: boolean;
  columns?: string[];
  rows?: Record<string, any>[];
  row_count?: number;
  rows_affected?: number;
  duration_ms?: number;
  error?: string;
  sql?: string;
}

function cleanConfigPayload(config: Partial<ConnectionConfig>): Record<string, any> {
  const c: any = { ...config };
  
  const userVal = c.user || c.username;
  if (userVal) {
    c.user = String(userVal);
  } else {
    delete c.user;
  }
  delete c.username;

  if (c.port !== undefined && c.port !== null && String(c.port).trim() !== '') {
    c.port = Number(c.port);
  } else {
    delete c.port;
  }

  if (c.adapter === 'postgres' && (!c.database || String(c.database).trim() === '')) {
    c.database = 'postgres';
  }

  return c;
}

export async function fetchInitialState(connectionId?: string, schema?: string) {
  if (isTauri()) {
    return await invokeTauri<{
      connections: ConnectionConfig[];
      active_connection: ConnectionConfig | null;
      schemas: string[];
      selected_schema: string;
      tables: TableItem[];
    }>('get_initial_state', { connectionId, schema });
  }

  const params = new URLSearchParams();
  if (connectionId) params.set('connection_id', connectionId);
  if (schema) params.set('schema', schema);

  const res = await fetch(`/?${params.toString()}`, {
    headers: { 'Accept': 'application/json', 'X-Inertia': 'true' }
  });
  const data = await res.json();
  return data.props;
}

export async function fetchConnections(): Promise<ConnectionConfig[]> {
  if (isTauri()) {
    return await invokeTauri<ConnectionConfig[]>('get_connections');
  }
  const res = await fetch('/connections', { headers: { 'Accept': 'application/json' } });
  return await res.json();
}

export async function saveConnection(config: Partial<ConnectionConfig>): Promise<ConnectionConfig> {
  const cleaned = cleanConfigPayload(config);
  if (isTauri()) {
    return await invokeTauri<ConnectionConfig>('save_connection', { config: cleaned });
  }
  const res = await fetch('/connections', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({ connection: cleaned })
  });
  return await res.json();
}

export async function deleteConnection(id: string): Promise<void> {
  if (isTauri()) {
    await invokeTauri('delete_connection', { id });
    return;
  }
  await fetch(`/connections/${id}`, {
    method: 'DELETE',
    headers: { 'Accept': 'application/json' }
  });
}

export async function testConnection(config: Partial<ConnectionConfig>) {
  const cleaned = cleanConfigPayload(config);
  if (isTauri()) {
    return await invokeTauri<{
      success: boolean;
      message?: string;
      error?: string;
      server_version?: string;
      database?: string;
      adapter?: string;
    }>('test_connection', { config: cleaned });
  }
  const res = await fetch('/connections/test', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({ connection: cleaned })
  });
  return await res.json();
}

export async function discoverDatabases(config: Partial<ConnectionConfig>): Promise<{ success: boolean; databases?: string[]; message?: string; is_pgbouncer?: boolean }> {
  const cleaned = cleanConfigPayload(config);
  if (isTauri()) {
    try {
      const dbs = await invokeTauri<string[]>('discover_databases', { config: cleaned });
      return {
        success: true,
        databases: dbs,
        message: `Discovered ${dbs.length} database(s)`
      };
    } catch (err: any) {
      return {
        success: false,
        message: err?.message || String(err)
      };
    }
  }
  const res = await fetch('/connections/discover', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify(cleaned)
  });
  return await res.json();
}

export async function fetchSchemas(connectionId: string): Promise<string[]> {
  if (isTauri()) {
    return await invokeTauri<string[]>('get_schemas', { connectionId });
  }
  const res = await fetch(`/api/tables?connection_id=${connectionId}`, {
    headers: { 'Accept': 'application/json' }
  });
  const data = await res.json();
  return data.schemas || ['main'];
}

export async function fetchTables(connectionId: string, schema?: string): Promise<TableItem[]> {
  if (isTauri()) {
    return await invokeTauri<TableItem[]>('get_tables', { connectionId, schema });
  }
  const params = new URLSearchParams({ connection_id: connectionId });
  if (schema) params.set('schema', schema);
  const res = await fetch(`/api/tables?${params.toString()}`, {
    headers: { 'Accept': 'application/json' }
  });
  const data = await res.json();
  return data.tables || [];
}

export async function fetchTableStructure(connectionId: string, table: string, schema?: string): Promise<TableStructure> {
  if (isTauri()) {
    return await invokeTauri<TableStructure>('get_table_structure', {
      connectionId,
      table,
      schema
    });
  }
  const params = new URLSearchParams({ connection_id: connectionId, table });
  if (schema) params.set('schema', schema);
  const res = await fetch(`/api/structure?${params.toString()}`, {
    headers: { 'Accept': 'application/json' }
  });
  return await res.json();
}

export async function executeQuery(connectionId: string | undefined, sql: string, limit = 1000): Promise<QueryResult> {
  if (isTauri()) {
    return await invokeTauri<QueryResult>('execute_query', {
      connectionId,
      sql,
      limit: limit ? Number(limit) : 1000
    });
  }
  const res = await fetch('/api/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
    body: JSON.stringify({ connection_id: connectionId, sql, limit })
  });
  return await res.json();
}
