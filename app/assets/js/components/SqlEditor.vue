<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue';
import { useVirtualizer } from '@tanstack/vue-virtual';
import {
  Play,
  Loader2,
  Download,
  Terminal,
  AlertCircle,
  Clock,
  CheckCircle2,
  FileJson,
  Braces,
  RotateCcw,
  Maximize2,
  Minimize2
} from 'lucide-vue-next';
import { highlightSql } from '../utils/sqlHighlighter';
import { highlightJsonInline } from '../utils/jsonHighlighter';
import { useColumnResizing } from '../utils/useColumnResizing';
import { executeQuery } from '../utils/api';

const props = defineProps<{
  connectionId?: string;
  defaultTable?: string;
  schema?: string;
}>();

const emit = defineEmits<{
  (e: 'inspect-value', payload: { col: string; val: any }): void;
}>();

const sql = ref('');
const executing = ref(false);
const isEditorFullscreen = ref(false);
const isResultsFullscreen = ref(false);

const textareaRef = ref<HTMLTextAreaElement | null>(null);
const preRef = ref<HTMLElement | null>(null);
const gutterRef = ref<HTMLElement | null>(null);
const editorHeight = ref(240);
const isResizingEditor = ref(false);

const highlightedSql = computed(() => highlightSql(sql.value));

const lineCount = computed(() => {
  if (!sql.value) return 1;
  return sql.value.split('\n').length;
});

function handleScroll() {
  if (!textareaRef.value) return;
  const { scrollTop, scrollLeft } = textareaRef.value;
  if (preRef.value) {
    preRef.value.scrollTop = scrollTop;
    preRef.value.scrollLeft = scrollLeft;
  }
  if (gutterRef.value) {
    gutterRef.value.scrollTop = scrollTop;
  }
}

function toggleEditorFullscreen() {
  isEditorFullscreen.value = !isEditorFullscreen.value;
  if (isEditorFullscreen.value) {
    isResultsFullscreen.value = false;
  }
}

function toggleResultsFullscreen() {
  isResultsFullscreen.value = !isResultsFullscreen.value;
  if (isResultsFullscreen.value) {
    isEditorFullscreen.value = false;
  }
}

function startResizingEditor(e: MouseEvent) {
  e.preventDefault();
  isResizingEditor.value = true;
  document.body.style.cursor = 'row-resize';
  document.body.style.userSelect = 'none';
  const startY = e.clientY;
  const startH = editorHeight.value;

  function onMouseMove(event: MouseEvent) {
    const delta = event.clientY - startY;
    editorHeight.value = Math.max(90, Math.min(520, startH + delta));
  }

  function onMouseUp() {
    isResizingEditor.value = false;
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  }

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
}

const result = ref<{
  success: boolean;
  is_select?: boolean;
  columns?: string[];
  rows?: Record<string, any>[];
  row_count?: number;
  rows_affected?: number;
  duration_ms?: number;
  error?: string;
  sql?: string;
} | null>(null);

const resultsParentRef = ref<HTMLElement | null>(null);

// Column Resizing for SQL query results
const {
  columnWidths,
  resizingCol,
  getColumnWidth,
  startResize,
  autoFitColumn,
  resetAllWidths,
} = useColumnResizing({
  defaultWidth: 160,
  minWidth: 70,
  maxWidth: 1200,
});

const totalSqlResultWidth = computed(() => {
  if (!result.value?.columns) return 0;
  const colsWidth = result.value.columns.reduce((sum, col) => {
    return sum + getColumnWidth(col);
  }, 0);
  return 48 + colsWidth;
});

function handleSqlColAutoFit(col: string) {
  autoFitColumn(col, result.value?.rows || []);
}

// Virtualizer for SQL results
const rowVirtualizer = useVirtualizer(
  computed(() => ({
    count: result.value?.rows ? result.value.rows.length : 0,
    getScrollElement: () => resultsParentRef.value,
    estimateSize: () => 34,
    overscan: 20,
  }))
);

function handleGlobalKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    if (isEditorFullscreen.value) isEditorFullscreen.value = false;
    if (isResultsFullscreen.value) isResultsFullscreen.value = false;
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleGlobalKeyDown);
  if (props.defaultTable) {
    sql.value = `SELECT * FROM ${props.defaultTable} LIMIT 100;`;
  } else {
    sql.value = `SELECT 1 AS status, 'Hello from Tabami' AS message, CURRENT_TIMESTAMP AS now;`;
  }
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalKeyDown);
});

async function runQuery() {
  if (!sql.value.trim() || executing.value) return;

  executing.value = true;
  result.value = null;

  try {
    const data = await executeQuery(props.connectionId, sql.value, 1000);
    result.value = data;

    await nextTick();
    if (rowVirtualizer.value && typeof rowVirtualizer.value.scrollToIndex === 'function') {
      rowVirtualizer.value.scrollToIndex(0, { align: 'start' });
    } else if (resultsParentRef.value) {
      resultsParentRef.value.scrollTop = 0;
    }
  } catch (err: any) {
    result.value = {
      success: false,
      error: err.message || 'Error executing SQL query.',
    };
  } finally {
    executing.value = false;
  }
}

function handleKeyDown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    runQuery();
    return;
  }

  if (e.key === 'Tab') {
    e.preventDefault();
    const el = textareaRef.value;
    if (!el) return;
    const start = el.selectionStart;
    const end = el.selectionEnd;

    if (start === end) {
      const val = sql.value;
      sql.value = val.substring(0, start) + '  ' + val.substring(end);
      nextTick(() => {
        el.selectionStart = el.selectionEnd = start + 2;
      });
    } else {
      const val = sql.value;
      const before = val.substring(0, start);
      const sel = val.substring(start, end);
      const after = val.substring(end);
      if (e.shiftKey) {
        const lines = sel.split('\n').map((l) => l.startsWith('  ') ? l.substring(2) : (l.startsWith(' ') ? l.substring(1) : l));
        const newSel = lines.join('\n');
        sql.value = before + newSel + after;
        nextTick(() => {
          el.selectionStart = start;
          el.selectionEnd = start + newSel.length;
        });
      } else {
        const lines = sel.split('\n').map((l) => '  ' + l);
        const newSel = lines.join('\n');
        sql.value = before + newSel + after;
        nextTick(() => {
          el.selectionStart = start;
          el.selectionEnd = start + newSel.length;
        });
      }
    }
  }
}

function exportAsJson() {
  if (!result.value?.rows) return;
  const blob = new Blob([JSON.stringify(result.value.rows, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `query_result_${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

function exportAsCsv() {
  if (!result.value?.rows || !result.value.columns) return;
  const cols = result.value.columns;
  const csvRows = [cols.join(',')];

  for (const row of result.value.rows) {
    const values = cols.map((col) => {
      const val = row[col];
      if (val === null || val === undefined) return '';
      const str = typeof val === 'object' ? JSON.stringify(val) : String(val);
      return `"${str.replace(/"/g, '""')}"`;
    });
    csvRows.push(values.join(','));
  }

  const blob = new Blob([csvRows.join('\n')], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `query_result_${Date.now()}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

function isJsonLike(val: any): boolean {
  if (typeof val === 'object' && val !== null) return true;
  if (typeof val === 'string' && (val.startsWith('{') || val.startsWith('['))) {
    try {
      JSON.parse(val);
      return true;
    } catch {
      return false;
    }
  }
  return false;
}

function getJsonMeta(val: any): { isJson: boolean; isArray: boolean; count: number; preview: string } {
  if (val === null || val === undefined) {
    return { isJson: false, isArray: false, count: 0, preview: '' };
  }
  if (typeof val === 'object') {
    const isArray = Array.isArray(val);
    const count = isArray ? val.length : Object.keys(val).length;
    let preview = '';
    try {
      preview = JSON.stringify(val);
    } catch {
      preview = String(val);
    }
    return { isJson: true, isArray, count, preview };
  }
  if (typeof val === 'string' && (val.startsWith('{') || val.startsWith('['))) {
    try {
      const parsed = JSON.parse(val);
      const isArray = Array.isArray(parsed);
      const count = isArray ? parsed.length : (typeof parsed === 'object' && parsed !== null ? Object.keys(parsed).length : 0);
      return { isJson: true, isArray, count, preview: val };
    } catch {
      return { isJson: false, isArray: false, count: 0, preview: val };
    }
  }
  return { isJson: false, isArray: false, count: 0, preview: String(val) };
}
</script>

<template>
  <div class="flex flex-col h-full bg-sumi-950 select-none overflow-hidden text-slate-200">
    <!-- SQL Editor Section -->
    <div
      :class="[
        isEditorFullscreen
          ? 'fixed inset-0 z-50 bg-sumi-950 flex flex-col shadow-2xl'
          : 'shrink-0 flex flex-col bg-sumi-950 border-b border-sumi-750'
      ]"
    >
      <!-- Top Query Toolbar -->
      <div class="h-11 px-4 bg-sumi-900 border-b border-sumi-750 flex items-center justify-between gap-4 shrink-0">
        <div class="flex items-center gap-3">
          <button
            @click="runQuery"
            :disabled="executing || !sql.trim()"
            class="px-3.5 py-1.5 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-700 hover:from-emerald-500 hover:to-teal-600 text-xs font-semibold text-white shadow-md shadow-emerald-950/60 border border-emerald-400/30 transition flex items-center gap-2 disabled:opacity-50"
          >
            <Loader2 v-if="executing" class="w-3.5 h-3.5 animate-spin" />
            <Play v-else class="w-3.5 h-3.5 fill-current" />
            <span>Execute Query</span>
            <kbd class="ml-1 text-[10px] bg-emerald-800/90 text-emerald-100 px-1.5 py-0.5 rounded font-mono">⌘↵</kbd>
          </button>
        </div>

        <div class="flex items-center gap-2">
          <!-- Editor Fullscreen Toggle Button -->
          <button
            @click="toggleEditorFullscreen"
            class="p-1.5 rounded-xl bg-sumi-850 hover:bg-sumi-800 text-sumi-400 hover:text-white border border-sumi-750 transition shadow-sm"
            :title="isEditorFullscreen ? 'Exit Full Screen (Esc)' : 'Open Editor in Full Screen'"
          >
            <Minimize2 v-if="isEditorFullscreen" class="w-4 h-4 text-yamabuki-400" />
            <Maximize2 v-else class="w-4 h-4" />
          </button>
        </div>
      </div>

      <!-- SQL Code Editor with Synced Line Numbers & Highlighting -->
      <div
        :class="[
          isEditorFullscreen ? 'flex-1 min-h-0' : 'shrink-0',
          'relative bg-sumi-950 flex flex-col group/editor overflow-hidden'
        ]"
        :style="isEditorFullscreen ? {} : { height: `${editorHeight}px` }"
      >
        <div class="flex-1 flex overflow-hidden relative">
          <!-- Line Numbers Gutter -->
          <div
            ref="gutterRef"
            class="w-10 py-3 pr-2.5 select-none text-right font-mono text-[11px] text-sumi-500 bg-sumi-950 border-r border-sumi-750 shrink-0 overflow-hidden leading-relaxed"
          >
            <div v-for="n in lineCount" :key="n">{{ n }}</div>
          </div>

          <!-- Editor Container with Synced Highlight Layer -->
          <div class="flex-1 relative overflow-hidden bg-sumi-950">
            <pre
              ref="preRef"
              class="absolute inset-0 p-3 font-mono text-xs leading-relaxed whitespace-pre-wrap break-words pointer-events-none overflow-hidden select-none text-slate-100 m-0 bg-transparent border-0 font-normal"
            ><code v-html="highlightedSql"></code></pre>

            <textarea
              ref="textareaRef"
              v-model="sql"
              @scroll="handleScroll"
              @keydown="handleKeyDown"
              placeholder="Write your SQL query here... Press ⌘+Enter or Ctrl+Enter to execute"
              class="sql-editor-input absolute inset-0 p-3 font-mono text-xs leading-relaxed whitespace-pre-wrap break-words bg-transparent text-transparent caret-emerald-700 dark:caret-matcha-400 focus:outline-none resize-none overflow-auto selection:bg-emerald-500/25 selection:text-transparent placeholder:text-sumi-500 border-0 m-0"
              spellcheck="false"
              autocapitalize="off"
              autocomplete="off"
              autocorrect="off"
            ></textarea>
          </div>
        </div>

        <!-- Vertical Resize Handle -->
        <div
          v-if="!isEditorFullscreen"
          @mousedown="startResizingEditor"
          title="Drag to resize editor height"
          class="h-1.5 w-full cursor-row-resize z-20 group/rowresizer flex items-center justify-center bg-sumi-900 hover:bg-emerald-500/30 transition-colors shrink-0"
        >
          <div
            :class="[
              'h-0.5 w-12 rounded-full transition-colors',
              isResizingEditor ? 'bg-matcha-400' : 'bg-sumi-700 group-hover/rowresizer:bg-matcha-400'
            ]"
          />
        </div>
      </div>
    </div>

    <!-- Results Section -->
    <div
      :class="[
        isResultsFullscreen
          ? 'fixed inset-0 z-50 bg-sumi-950 flex flex-col shadow-2xl'
          : 'flex-1 min-h-0 overflow-hidden flex flex-col bg-sumi-950'
      ]"
    >
      <!-- Query Status Bar -->
      <div
        v-if="result"
        :class="[
          'h-9 px-4 flex items-center justify-between text-xs font-mono shrink-0 border-b',
          result.success
            ? 'bg-sumi-900 border-sumi-750 text-slate-300'
            : 'bg-rose-950/40 border-rose-900/60 text-rose-300'
        ]"
      >
        <div class="flex items-center gap-3 text-[11px]">
          <template v-if="result.success">
            <span class="flex items-center gap-1 text-matcha-400 font-medium">
              <CheckCircle2 class="w-3.5 h-3.5" />
              Query Executed
            </span>
            <span v-if="result.duration_ms !== undefined" class="text-sumi-400 flex items-center gap-1">
              <Clock class="w-3 h-3 text-sumi-500" />
              {{ result.duration_ms }} ms
            </span>
            <span v-if="result.row_count !== undefined" class="text-sumi-400">
              • {{ result.row_count }} rows returned
            </span>
            <span v-if="result.rows_affected !== null && result.rows_affected !== undefined" class="text-sumi-400">
              • {{ result.rows_affected }} rows affected
            </span>
          </template>

          <template v-else>
            <span class="flex items-center gap-1.5 text-rose-400 font-medium">
              <AlertCircle class="w-3.5 h-3.5 shrink-0" />
              {{ result.error }}
            </span>
          </template>
        </div>

        <div class="flex items-center gap-2">
          <button
            v-if="result?.rows && result.rows.length > 0"
            @click="exportAsCsv"
            class="px-2 py-0.5 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-slate-300 hover:text-white border border-sumi-750 text-[11px] font-sans transition flex items-center gap-1"
            title="Download CSV"
          >
            <Download class="w-3 h-3 text-emerald-400" />
            <span>CSV</span>
          </button>
          <button
            v-if="result?.rows && result.rows.length > 0"
            @click="exportAsJson"
            class="px-2 py-0.5 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-slate-300 hover:text-white border border-sumi-750 text-[11px] font-sans transition flex items-center gap-1"
            title="Download JSON"
          >
            <Download class="w-3 h-3 text-aizome-400" />
            <span>JSON</span>
          </button>
          <button
            v-if="Object.keys(columnWidths).length > 0"
            @click="resetAllWidths"
            class="px-2 py-0.5 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-sumi-400 hover:text-white border border-sumi-750 text-[11px] font-sans transition flex items-center gap-1"
            title="Reset column widths"
          >
            <RotateCcw class="w-3 h-3" />
            <span>Reset Widths</span>
          </button>
          <!-- Results Fullscreen Toggle Button -->
          <button
            @click="toggleResultsFullscreen"
            class="p-1 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-sumi-400 hover:text-white border border-sumi-750 transition"
            :title="isResultsFullscreen ? 'Exit Full Screen (Esc)' : 'Open Results in Full Screen'"
          >
            <Minimize2 v-if="isResultsFullscreen" class="w-3.5 h-3.5 text-yamabuki-400" />
            <Maximize2 v-else class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <!-- Results Viewport (Virtualized Grid) -->
      <div ref="resultsParentRef" class="flex-1 overflow-auto relative font-mono text-xs bg-sumi-950">
        <template v-if="result?.rows && result.rows.length > 0 && result.columns">
          <div
            class="min-w-full inline-block"
            :style="{ width: `${totalSqlResultWidth}px`, minWidth: '100%' }"
          >
            <!-- Sticky Header -->
            <div class="sticky top-0 z-20 flex bg-sumi-900 border-b border-sumi-750 shadow-sm select-none backdrop-blur-sm">
              <div class="w-12 px-2 py-2 text-center text-[10px] font-semibold text-sumi-500 border-r border-sumi-750 bg-sumi-900 shrink-0 sticky left-0 z-30">
                #
              </div>
              <div
                v-for="col in result.columns"
                :key="col"
                :style="{
                  width: `${getColumnWidth(col)}px`,
                  minWidth: `${getColumnWidth(col)}px`,
                  maxWidth: `${getColumnWidth(col)}px`,
                }"
                class="relative shrink-0 px-3 py-2 text-left border-r border-sumi-750 text-[11px] font-semibold text-slate-300 truncate flex items-center justify-between group"
              >
                <span class="truncate pr-2">{{ col }}</span>

                <div
                  @mousedown.stop="startResize(col, $event)"
                  @dblclick.stop.prevent="handleSqlColAutoFit(col)"
                  @click.stop
                  title="Drag to resize column, double-click to auto-fit"
                  :class="[
                    'absolute top-0 right-0 w-3 h-full cursor-col-resize z-30 select-none flex items-center justify-end group/resizer transition-colors',
                    resizingCol === col ? 'bg-aizome-500/30' : 'hover:bg-aizome-500/20'
                  ]"
                >
                  <div
                    :class="[
                      'w-[2px] h-full transition-colors',
                      resizingCol === col ? 'bg-aizome-400 shadow-sm' : 'bg-transparent group-hover/resizer:bg-aizome-400'
                    ]"
                  />
                </div>
              </div>
            </div>

            <!-- Virtual Body -->
            <div :style="{ height: `${rowVirtualizer.getTotalSize()}px`, position: 'relative', width: '100%' }">
              <div
                v-for="virtualRow in rowVirtualizer.getVirtualItems()"
                :key="virtualRow.index"
                :class="[
                  'flex absolute top-0 left-0 w-full border-b border-sumi-800/40 hover:bg-sumi-850/50 transition',
                  virtualRow.index % 2 === 0 ? 'bg-sumi-950' : 'bg-sumi-900/30'
                ]"
                :style="{
                  height: `${virtualRow.size}px`,
                  transform: `translateY(${virtualRow.start}px)`,
                }"
              >
                <div class="w-12 px-2 py-1.5 text-center text-[10px] border-r border-sumi-800/60 bg-sumi-950/95 text-sumi-500 shrink-0 sticky left-0 z-10 font-mono">
                  {{ virtualRow.index + 1 }}
                </div>

                <div
                  v-for="col in result.columns"
                  :key="col"
                  :style="{
                    width: `${getColumnWidth(col)}px`,
                    minWidth: `${getColumnWidth(col)}px`,
                    maxWidth: `${getColumnWidth(col)}px`,
                  }"
                  class="shrink-0 px-3 py-1.5 border-r border-sumi-800/40 truncate flex items-center justify-between text-slate-300 group/cell relative"
                >
                  <!-- NULL -->
                  <span v-if="result.rows[virtualRow.index][col] === null || result.rows[virtualRow.index][col] === undefined" class="text-sumi-500 italic text-[10px]">
                    NULL
                  </span>

                  <!-- Boolean -->
                  <span
                    v-else-if="typeof result.rows[virtualRow.index][col] === 'boolean'"
                    :class="[
                      'px-1.5 py-0.5 rounded text-[10px] font-bold font-sans',
                      result.rows[virtualRow.index][col]
                        ? 'bg-matcha-500/10 text-matcha-400 border border-matcha-500/20'
                        : 'bg-sumi-900 text-sumi-400 border border-sumi-750'
                    ]"
                  >
                    {{ result.rows[virtualRow.index][col] ? 'TRUE' : 'FALSE' }}
                  </span>

                  <!-- JSON -->
                  <div
                    v-else-if="isJsonLike(result.rows[virtualRow.index][col])"
                    @click="emit('inspect-value', { col: col, val: result.rows[virtualRow.index][col] })"
                    class="truncate flex items-center gap-2 cursor-pointer group/json w-full"
                  >
                    <span
                      :class="[
                        'px-1.5 py-0.5 rounded text-[10px] font-mono font-semibold flex items-center gap-1 border shrink-0 transition',
                        getJsonMeta(result.rows[virtualRow.index][col]).isArray
                          ? 'bg-aizome-950/80 text-aizome-300 border-aizome-800/80 group-hover/json:border-aizome-500'
                          : 'bg-yamabuki-950/80 text-yamabuki-300 border-yamabuki-800/80 group-hover/json:border-yamabuki-500'
                      ]"
                    >
                      <Braces class="w-2.5 h-2.5" />
                      <span>{{ getJsonMeta(result.rows[virtualRow.index][col]).count }} {{ getJsonMeta(result.rows[virtualRow.index][col]).isArray ? 'items' : 'keys' }}</span>
                    </span>

                    <span
                      class="truncate font-mono text-[11px] select-text"
                      v-html="highlightJsonInline(getJsonMeta(result.rows[virtualRow.index][col]).preview, 140)"
                    ></span>

                    <button
                      @click.stop="emit('inspect-value', { col: col, val: result.rows[virtualRow.index][col] })"
                      class="opacity-0 group-hover/cell:opacity-100 ml-auto p-0.5 rounded bg-sumi-800 text-yamabuki-300 hover:text-white hover:bg-sumi-700 transition shrink-0"
                      title="Inspect JSON"
                    >
                      <FileJson class="w-3 h-3" />
                    </button>
                  </div>

                  <!-- Numbers / IDs -->
                  <span v-else-if="typeof result.rows[virtualRow.index][col] === 'number' || (col.toLowerCase().includes('id') && !isNaN(Number(result.rows[virtualRow.index][col])))" class="truncate text-aizome-300 font-mono">
                    {{ result.rows[virtualRow.index][col] }}
                  </span>

                  <!-- Default Text -->
                  <span v-else class="truncate text-slate-300">
                    {{ result.rows[virtualRow.index][col] }}
                  </span>

                  <button
                    v-if="String(result.rows[virtualRow.index][col] || '').length > 30 && !isJsonLike(result.rows[virtualRow.index][col])"
                    @click.stop="emit('inspect-value', { col: col, val: result.rows[virtualRow.index][col] })"
                    class="opacity-0 group-hover/cell:opacity-100 p-0.5 rounded bg-sumi-800 text-sumi-400 hover:text-white transition shrink-0 ml-1"
                    title="Expand Value"
                  >
                    <FileJson class="w-3 h-3" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </template>

        <div v-else-if="!result" class="h-full flex flex-col items-center justify-center text-sumi-500 text-xs gap-2">
          <Terminal class="w-8 h-8 opacity-40 text-sumi-500" />
          <p>Run a query above to view execution results</p>
        </div>

        <div v-else-if="result.success && (!result.rows || result.rows.length === 0)" class="h-full flex flex-col items-center justify-center text-sumi-500 text-xs gap-2">
          <CheckCircle2 class="w-6 h-6 text-matcha-400" />
          <p>Statement executed successfully (0 rows returned)</p>
        </div>
      </div>
    </div>
  </div>
</template>
