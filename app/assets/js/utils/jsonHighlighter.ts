/**
 * Lightweight JSON Syntax Highlighter
 * Zero-dependency, regex-based tokenizer and highlighter for JSON in Tabami.
 * Designed for both Dark (Sumi/Urushi) and Light (Washi) themes.
 */

export function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Highlights matches of a search query inside an escaped string with a glowing mark.
 */
export function applySearchHighlight(escapedText: string, searchQuery?: string): string {
  if (!searchQuery || !searchQuery.trim()) return escapedText;
  const q = escapeHtml(searchQuery.trim());
  const regex = new RegExp(`(${q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
  return escapedText.replace(
    regex,
    '<mark class="bg-amber-400/30 text-amber-200 dark:text-amber-300 font-bold rounded px-0.5 shadow-sm">$1</mark>'
  );
}

/**
 * Formats and syntax-highlights raw JSON text into styled HTML with Tailwind classes.
 */
export function highlightJson(json: string, searchQuery?: string): string {
  if (!json && json !== '0' && json !== 'false') return '';

  const regex = /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?|[{}\[\]]|,|:|\/\/[^\n]*|\/\*[\s\S]*?\*\/)/g;

  let highlighted = json.replace(regex, (match) => {
    // 1. Comments
    if (match.startsWith('//') || match.startsWith('/*')) {
      return `<span class="text-slate-400 dark:text-sumi-500 italic font-normal">${applySearchHighlight(escapeHtml(match), searchQuery)}</span>`;
    }

    // 2. Strings & Keys
    if (match.startsWith('"')) {
      if (/:$/.test(match.trim())) {
        const colonIdx = match.lastIndexOf(':');
        const keyPart = match.slice(0, colonIdx);
        const colonPart = match.slice(colonIdx);
        const highlightedKey = applySearchHighlight(escapeHtml(keyPart), searchQuery);
        return `<span class="text-indigo-600 dark:text-indigo-300 font-semibold">${highlightedKey}</span><span class="text-slate-400 dark:text-sumi-500 font-normal">${escapeHtml(colonPart)}</span>`;
      }
      const highlightedStr = applySearchHighlight(escapeHtml(match), searchQuery);
      return `<span class="text-emerald-700 dark:text-emerald-300 font-normal">${highlightedStr}</span>`;
    }

    // 3. Booleans
    if (match === 'true') {
      return `<span class="text-emerald-600 dark:text-matcha-400 font-bold tracking-wide">${applySearchHighlight('true', searchQuery)}</span>`;
    }
    if (match === 'false') {
      return `<span class="text-rose-600 dark:text-rose-400 font-bold tracking-wide">${applySearchHighlight('false', searchQuery)}</span>`;
    }

    // 4. Null
    if (match === 'null') {
      return `<span class="text-slate-500 dark:text-slate-400 italic font-semibold">${applySearchHighlight('null', searchQuery)}</span>`;
    }

    // 5. Numbers
    if (/^-?\d/.test(match)) {
      return `<span class="text-amber-600 dark:text-yamabuki-400 font-mono font-medium">${applySearchHighlight(escapeHtml(match), searchQuery)}</span>`;
    }

    // 6. Braces & Brackets
    if (match === '{' || match === '}') {
      return `<span class="text-amber-600 dark:text-amber-400 font-bold">${escapeHtml(match)}</span>`;
    }
    if (match === '[' || match === ']') {
      return `<span class="text-cyan-600 dark:text-cyan-400 font-bold">${escapeHtml(match)}</span>`;
    }

    // 7. Delimiters
    if (match === ',' || match === ':') {
      return `<span class="text-slate-400 dark:text-sumi-500 font-normal">${escapeHtml(match)}</span>`;
    }

    return escapeHtml(match);
  });

  if (json.endsWith('\n')) {
    highlighted += ' ';
  }

  return highlighted;
}

/**
 * Compact inline JSON syntax highlighter for table cell previews.
 */
export function highlightJsonInline(json: string, maxLength: number = 180): string {
  if (!json) return '';
  let compact = json.replace(/\s+/g, ' ').trim();
  if (compact.length > maxLength) {
    compact = compact.slice(0, maxLength) + '...';
  }
  return highlightJson(compact);
}
