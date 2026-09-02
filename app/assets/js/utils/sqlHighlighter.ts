/**
 * Lightweight SQL Syntax Highlighter
 * Zero-dependency, regex-based tokenizer and highlighter for SQL queries in Tabami.
 */

const KEYWORDS = new Set([
  'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'IS', 'NULL',
  'LIKE', 'ILIKE', 'BETWEEN', 'EXISTS', 'AS', 'DISTINCT', 'ALL', 'ANY',
  'JOIN', 'INNER', 'LEFT', 'RIGHT', 'FULL', 'OUTER', 'CROSS', 'NATURAL', 'ON', 'USING',
  'GROUP', 'BY', 'HAVING', 'ORDER', 'ASC', 'DESC', 'NULLS', 'FIRST', 'LAST',
  'LIMIT', 'OFFSET', 'FETCH', 'NEXT', 'ROWS', 'ONLY',
  'UNION', 'EXCEPT', 'INTERSECT',
  'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'TRUNCATE',
  'CREATE', 'ALTER', 'DROP', 'TABLE', 'VIEW', 'INDEX', 'SCHEMA', 'DATABASE',
  'COLUMN', 'ADD', 'CONSTRAINT', 'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES',
  'CHECK', 'UNIQUE', 'DEFAULT', 'CASCADE', 'RESTRICT',
  'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
  'WITH', 'RECURSIVE', 'OVER', 'PARTITION', 'WINDOW',
  'BEGIN', 'COMMIT', 'ROLLBACK', 'TRANSACTION', 'SAVEPOINT',
  'GRANT', 'REVOKE', 'EXPLAIN', 'ANALYZE', 'VACUUM', 'RETURNING',
  'TRUE', 'FALSE', 'IF'
]);

const TYPES = new Set([
  'INT', 'INTEGER', 'BIGINT', 'SMALLINT', 'TINYINT', 'SERIAL', 'BIGSERIAL',
  'DECIMAL', 'NUMERIC', 'REAL', 'FLOAT', 'DOUBLE', 'PRECISION', 'MONEY',
  'VARCHAR', 'CHAR', 'CHARACTER', 'VARYING', 'TEXT', 'STRING', 'CITEXT',
  'BOOLEAN', 'BOOL', 'BIT',
  'DATE', 'TIME', 'TIMESTAMP', 'TIMESTAMPTZ', 'INTERVAL', 'DATETIME',
  'JSON', 'JSONB', 'XML', 'UUID', 'BYTEA', 'BLOB', 'BINARY', 'VARBINARY',
  'ARRAY', 'POINT', 'GEOMETRY', 'GEOGRAPHY'
]);

const FUNCTIONS = new Set([
  'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'EVERY',
  'COALESCE', 'NULLIF', 'GREATEST', 'LEAST',
  'ROUND', 'FLOOR', 'CEIL', 'CEILING', 'ABS', 'MOD', 'POWER', 'SQRT', 'SIGN',
  'NOW', 'CURRENT_TIMESTAMP', 'CURRENT_DATE', 'CURRENT_TIME', 'LOCALTIMESTAMP',
  'DATE_TRUNC', 'DATE_PART', 'EXTRACT', 'AGE', 'TO_CHAR', 'TO_DATE', 'TO_TIMESTAMP', 'TO_NUMBER',
  'CONCAT', 'CONCAT_WS', 'SUBSTRING', 'SUBSTR', 'LOWER', 'UPPER', 'TRIM', 'LTRIM', 'RTRIM',
  'LENGTH', 'CHAR_LENGTH', 'REPLACE', 'SPLIT_PART', 'POSITION', 'STRPOS', 'LPAD', 'RPAD',
  'CAST', 'CONVERT', 'TRY_CAST',
  'ROW_NUMBER', 'RANK', 'DENSE_RANK', 'PERCENT_RANK', 'CUME_DIST', 'NTILE',
  'LAG', 'LEAD', 'FIRST_VALUE', 'LAST_VALUE', 'NTH_VALUE',
  'JSON_BUILD_OBJECT', 'JSONB_BUILD_OBJECT', 'JSON_BUILD_ARRAY', 'JSONB_BUILD_ARRAY',
  'JSON_AGG', 'JSONB_AGG', 'JSON_OBJECT_AGG', 'JSONB_OBJECT_AGG', 'JSON_EXTRACT_PATH',
  'GENERATE_SERIES', 'ARRAY_AGG', 'ARRAY_TO_STRING', 'STRING_AGG', 'UNNEST'
]);

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Parses raw SQL string into syntax-highlighted HTML with Tailwind classes.
 */
export function highlightSql(sql: string): string {
  if (!sql) return '';

  const regex = /(\/\*[\s\S]*?(?:\*\/|$))|((?:--|#)[^\n]*)|(\$[a-zA-Z0-9_]*\$[\s\S]*?(?:\$[a-zA-Z0-9_]*\$|$))|('(?:''|\\.|[^'\\\n])*(?:'|$))|("(?:"|\\.|[^"\\\n])*(?:"|$))|(`(?:\\.|[^`\\\n])*(?:`|$))|(\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|(::|->>|->|#>>|#>|<=|>=|!=|<>|\|\||[-+*/%=<>!&|^~])|(\b[a-zA-Z_][a-zA-Z0-9_]*\b)|([^\s\w])/g;

  let highlighted = sql.replace(regex, (match, blockComment, lineComment, dollarString, singleString, doubleString, backtickString, number, operator, word) => {
    if (blockComment || lineComment) {
      return `<span class="text-slate-400 dark:text-sumi-500 italic font-normal">${escapeHtml(match)}</span>`;
    }
    if (dollarString || singleString) {
      return `<span class="text-emerald-700 dark:text-matcha-300 font-normal">${escapeHtml(match)}</span>`;
    }
    if (doubleString || backtickString) {
      return `<span class="text-amber-700 dark:text-amber-300 font-normal">${escapeHtml(match)}</span>`;
    }
    if (number) {
      return `<span class="text-amber-600 dark:text-yamabuki-400 font-mono">${escapeHtml(match)}</span>`;
    }
    if (operator) {
      return `<span class="text-rose-600 dark:text-rose-300 font-medium">${escapeHtml(match)}</span>`;
    }
    if (word) {
      const upper = word.toUpperCase();
      if (upper === 'NULL' || upper === 'TRUE' || upper === 'FALSE') {
        return `<span class="text-rose-700 dark:text-ruby-400 font-semibold tracking-wide">${escapeHtml(match)}</span>`;
      }
      if (KEYWORDS.has(upper)) {
        return `<span class="text-indigo-700 dark:text-aizome-400 font-bold">${escapeHtml(match)}</span>`;
      }
      if (FUNCTIONS.has(upper)) {
        return `<span class="text-blue-700 dark:text-sky-300 font-semibold">${escapeHtml(match)}</span>`;
      }
      if (TYPES.has(upper)) {
        return `<span class="text-teal-700 dark:text-teal-400 font-medium">${escapeHtml(match)}</span>`;
      }
      return `<span class="text-sumi-50 font-normal">${escapeHtml(match)}</span>`;
    }
    return escapeHtml(match);
  });

  if (sql.endsWith('\n')) {
    highlighted += ' ';
  }

  return highlighted;
}
