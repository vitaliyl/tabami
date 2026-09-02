<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import {
  X,
  Copy,
  Check,
  FileJson,
  Code,
  ListTree,
  Sparkles,
  Minimize2,
  ArrowDownAZ,
  RotateCcw,
  Download,
  AlertCircle,
  CheckCircle2,
  Search,
  Maximize2
} from 'lucide-vue-next';
import { highlightJson } from '../utils/jsonHighlighter';
import JsonTreeNode from './JsonTreeNode.vue';
import { copyToClipboard as copyText } from '../utils/clipboard';

const props = withDefaults(
  defineProps<{
    isOpen: boolean;
    columnName: string;
    columnType?: string;
    rawValue: any;
    tableName?: string;
    schema?: string;
  }>(),
  {
    columnType: '',
    tableName: '',
    schema: 'public',
  }
);

const emit = defineEmits<{
  (e: 'close'): void;
}>();

const activeMode = ref<'code' | 'tree'>('code');
const editorContent = ref('');
const copied = ref(false);
const isExpandedModal = ref(false);

// Tree View State
const treeSearchQuery = ref('');
const codeSearchQuery = ref('');
const forceExpand = ref<boolean | null>(null);

// Code Editor Ref, Pre Ref & Line Numbers
const textareaRef = ref<HTMLTextAreaElement | null>(null);
const preRef = ref<HTMLElement | null>(null);
const lineNumbersRef = ref<HTMLDivElement | null>(null);

const highlightedJson = computed(() => {
  return highlightJson(editorContent.value, codeSearchQuery.value);
});

// Parse JSON / Object helpers
function getInitialString(val: any): string {
  if (val === null || val === undefined) return '';
  if (typeof val === 'object') {
    try {
      return JSON.stringify(val, null, 2);
    } catch {
      return String(val);
    }
  }
  if (typeof val === 'string') {
    try {
      const parsed = JSON.parse(val);
      return JSON.stringify(parsed, null, 2);
    } catch {
      return val;
    }
  }
  return String(val);
}

// Watch isOpen to initialize editor
watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      editorContent.value = getInitialString(props.rawValue);
      treeSearchQuery.value = '';
      codeSearchQuery.value = '';
      forceExpand.value = null;
      activeMode.value = 'code';

      nextTick(() => {
        if (textareaRef.value) {
          textareaRef.value.focus();
        }
      });
    }
  },
  { immediate: true }
);

// Syntax validation
const validationResult = computed(() => {
  const text = editorContent.value.trim();
  if (!text) {
    return { valid: true, isNull: true, error: null, line: null };
  }
  try {
    JSON.parse(text);
    return { valid: true, isNull: false, error: null, line: null };
  } catch (err: any) {
    const msg = err.message || 'Invalid JSON';
    const lineMatch = msg.match(/line\s+(\d+)/i) || msg.match(/position\s+(\d+)/i);
    return {
      valid: false,
      isNull: false,
      error: msg,
      line: lineMatch ? lineMatch[1] : null,
    };
  }
});

const isValidJson = computed(() => validationResult.value.valid);

const parsedJsonObject = computed(() => {
  const text = editorContent.value.trim();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
});

const linesCount = computed(() => {
  return editorContent.value.split('\n').length;
});

const characterCount = computed(() => {
  return editorContent.value.length;
});

// Editor Actions
function formatJson() {
  const text = editorContent.value.trim();
  if (!text) return;
  try {
    const parsed = JSON.parse(text);
    editorContent.value = JSON.stringify(parsed, null, 2);
  } catch (err: any) {
    // Cannot format
  }
}

function minifyJson() {
  const text = editorContent.value.trim();
  if (!text) return;
  try {
    const parsed = JSON.parse(text);
    editorContent.value = JSON.stringify(parsed);
  } catch (err: any) {
    // Cannot minify
  }
}

function sortJsonKeys() {
  const text = editorContent.value.trim();
  if (!text) return;
  try {
    const sortObject = (obj: any): any => {
      if (Array.isArray(obj)) return obj.map(sortObject);
      if (obj !== null && typeof obj === 'object') {
        return Object.keys(obj)
          .sort()
          .reduce((acc: Record<string, any>, key) => {
            acc[key] = sortObject(obj[key]);
            return acc;
          }, {});
      }
      return obj;
    };

    const parsed = JSON.parse(text);
    const sorted = sortObject(parsed);
    editorContent.value = JSON.stringify(sorted, null, 2);
  } catch (err: any) {
    // Cannot sort
  }
}

function resetToOriginal() {
  editorContent.value = getInitialString(props.rawValue);
}

async function copyToClipboard() {
  const ok = await copyText(editorContent.value);
  if (ok) {
    copied.value = true;
    setTimeout(() => (copied.value = false), 2000);
  }
}

function downloadJson() {
  const blob = new Blob([editorContent.value], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${props.tableName || 'data'}_${props.columnName}_${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

async function handleTreeCopyPath(path: string) {
  const ok = await copyText(path);
  if (ok) {
    copied.value = true;
    setTimeout(() => (copied.value = false), 1500);
  }
}

// Synchronized scrolling between line numbers, pre highlight layer, and textarea
function handleEditorScroll(e: Event) {
  const target = e.target as HTMLTextAreaElement;
  if (preRef.value) {
    preRef.value.scrollTop = target.scrollTop;
    preRef.value.scrollLeft = target.scrollLeft;
  }
  if (lineNumbersRef.value) {
    lineNumbersRef.value.scrollTop = target.scrollTop;
  }
}

// Global shortcut when modal is open
function handleGlobalKeyDown(e: KeyboardEvent) {
  if (!props.isOpen) return;
  if (e.key === 'Escape') {
    emit('close');
  }
}
</script>

<template>
  <div
    v-if="isOpen"
    @keydown="handleGlobalKeyDown"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-3 md:p-6 animate-in fade-in duration-150"
  >
    <div
      :class="[
        'bg-slate-900 border border-slate-700/80 rounded-2xl shadow-2xl overflow-hidden flex flex-col transition-all duration-200 select-text',
        isExpandedModal ? 'w-full h-[96vh]' : 'w-full max-w-4xl h-[85vh]'
      ]"
    >
      <!-- Top Header -->
      <div class="px-5 py-3.5 border-b border-slate-800 flex items-center justify-between bg-slate-900/90 shrink-0 gap-4">
        <!-- Title & Context -->
        <div class="flex items-center gap-3 min-w-0">
          <div class="p-2 rounded-xl bg-amber-500/10 text-amber-400 border border-amber-500/20 shrink-0">
            <FileJson class="w-5 h-5" />
          </div>
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h3 class="text-sm font-bold text-sumi-50 dark:text-white truncate">
                Value Inspector
              </h3>
              <span
                v-if="columnType"
                class="px-1.5 py-0.5 rounded text-[10px] font-mono uppercase bg-slate-800 text-amber-400 border border-slate-700"
              >
                {{ columnType }}
              </span>
            </div>
            <p class="text-xs text-slate-400 font-mono truncate flex items-center gap-1 mt-0.5">
              <span v-if="tableName" class="text-slate-500">{{ schema }}.{{ tableName }} &rsaquo;</span>
              <span class="text-emerald-400 font-semibold">{{ columnName }}</span>
            </p>
          </div>
        </div>

        <!-- Mode Selector & Top Actions -->
        <div class="flex items-center gap-2 shrink-0">
          <!-- View Mode Switcher -->
          <div class="bg-slate-950 p-0.5 rounded-lg border border-slate-800 flex items-center">
            <button
              @click="activeMode = 'code'"
              :class="[
                'px-2.5 py-1 rounded-md text-xs font-medium flex items-center gap-1.5 transition',
                activeMode === 'code'
                  ? 'bg-slate-800 text-emerald-400 shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              ]"
            >
              <Code class="w-3.5 h-3.5" />
              <span>Code</span>
            </button>
            <button
              @click="activeMode = 'tree'"
              :disabled="!isValidJson"
              :class="[
                'px-2.5 py-1 rounded-md text-xs font-medium flex items-center gap-1.5 transition disabled:opacity-40 disabled:cursor-not-allowed',
                activeMode === 'tree'
                  ? 'bg-slate-800 text-amber-400 shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              ]"
              :title="isValidJson ? 'Interactive Tree View' : 'Fix JSON syntax errors to view Tree'"
            >
              <ListTree class="w-3.5 h-3.5" />
              <span>Tree</span>
            </button>
          </div>

          <div class="h-4 w-px bg-slate-800 mx-0.5 hidden sm:block"></div>

          <!-- Quick Actions -->
          <button
            @click="copyToClipboard"
            class="p-1.5 rounded-lg border border-slate-800 bg-slate-850 hover:bg-slate-800 text-slate-300 hover:text-white transition text-xs flex items-center gap-1"
            title="Copy to clipboard"
          >
            <Check v-if="copied" class="w-4 h-4 text-emerald-400" />
            <Copy v-else class="w-4 h-4" />
            <span class="hidden sm:inline text-[11px]">{{ copied ? 'Copied' : 'Copy' }}</span>
          </button>

          <button
            @click="downloadJson"
            class="p-1.5 rounded-lg border border-slate-800 bg-slate-850 hover:bg-slate-800 text-slate-400 hover:text-white transition"
            title="Download JSON File"
          >
            <Download class="w-4 h-4" />
          </button>

          <button
            @click="isExpandedModal = !isExpandedModal"
            class="p-1.5 rounded-lg border border-slate-800 bg-slate-850 hover:bg-slate-800 text-slate-400 hover:text-white transition hidden md:block"
            :title="isExpandedModal ? 'Minimize Modal' : 'Maximize Modal'"
          >
            <Minimize2 v-if="isExpandedModal" class="w-4 h-4" />
            <Maximize2 v-else class="w-4 h-4" />
          </button>

          <button
            @click="emit('close')"
            class="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition ml-1"
            title="Close (Esc)"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
      </div>

      <!-- Secondary Toolbar (Formatters & Helpers) -->
      <div class="px-5 py-2 bg-slate-950/90 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-2 shrink-0 text-xs select-none">
        <!-- Left: Format Tools -->
        <div class="flex items-center gap-1.5 flex-wrap">
          <button
            @click="formatJson"
            class="px-2 py-1 rounded bg-slate-900 hover:bg-slate-800 border border-slate-800 text-emerald-400 hover:text-emerald-300 text-[11px] font-medium flex items-center gap-1 transition"
            title="Prettify JSON with 2-space indentation"
          >
            <Sparkles class="w-3 h-3" />
            <span>Prettify</span>
          </button>

          <button
            @click="minifyJson"
            class="px-2 py-1 rounded bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-300 hover:text-white text-[11px] font-medium flex items-center gap-1 transition"
            title="Minify JSON onto a single compact line"
          >
            <Minimize2 class="w-3 h-3" />
            <span>Minify</span>
          </button>

          <button
            @click="sortJsonKeys"
            class="px-2 py-1 rounded bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-300 hover:text-white text-[11px] font-medium flex items-center gap-1 transition"
            title="Sort object keys alphabetically"
          >
            <ArrowDownAZ class="w-3 h-3" />
            <span>Sort Keys</span>
          </button>

          <button
            @click="resetToOriginal"
            class="px-2 py-1 rounded bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-400 hover:text-white text-[11px] flex items-center gap-1 transition ml-1"
            title="Revert to original value"
          >
            <RotateCcw class="w-3 h-3" />
            <span>Reset</span>
          </button>
        </div>

        <!-- Right: Status / Validation Indicator & Search -->
        <div class="flex items-center gap-3 text-[11px]">
          <!-- Code Search Bar if in Code Mode -->
          <div v-if="activeMode === 'code'" class="flex items-center gap-1.5">
            <div class="relative">
              <Search class="w-3 h-3 text-slate-500 absolute left-2 top-1/2 -translate-y-1/2" />
              <input
                v-model="codeSearchQuery"
                type="text"
                placeholder="Find in JSON..."
                class="bg-slate-900 border border-slate-800 rounded pl-6 pr-2 py-0.5 text-[11px] text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 w-32 sm:w-40 font-mono"
              />
            </div>
            <button
              v-if="codeSearchQuery"
              @click="codeSearchQuery = ''"
              class="p-0.5 text-slate-400 hover:text-white"
              title="Clear search"
            >
              <X class="w-3 h-3" />
            </button>
          </div>

          <!-- Tree Search Bar if in Tree Mode -->
          <div v-if="activeMode === 'tree'" class="flex items-center gap-1.5">
            <div class="relative">
              <Search class="w-3 h-3 text-slate-500 absolute left-2 top-1/2 -translate-y-1/2" />
              <input
                v-model="treeSearchQuery"
                type="text"
                placeholder="Filter keys/values..."
                class="bg-slate-900 border border-slate-800 rounded pl-6 pr-2 py-0.5 text-[11px] text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 w-36 sm:w-44 font-mono"
              />
            </div>
            <button
              @click="forceExpand = true"
              class="px-1.5 py-0.5 text-[10px] rounded bg-slate-900 border border-slate-800 text-slate-400 hover:text-white"
            >
              Expand All
            </button>
            <button
              @click="forceExpand = false"
              class="px-1.5 py-0.5 text-[10px] rounded bg-slate-900 border border-slate-800 text-slate-400 hover:text-white"
            >
              Collapse All
            </button>
          </div>

          <!-- JSON Status Badge -->
          <div
            :class="[
              'px-2 py-0.5 rounded-full text-[10px] font-semibold flex items-center gap-1 border',
              isValidJson
                ? 'bg-emerald-950/60 text-emerald-400 border-emerald-800/60'
                : 'bg-rose-950/60 text-rose-400 border-rose-800/60'
            ]"
          >
            <CheckCircle2 v-if="isValidJson" class="w-3 h-3" />
            <AlertCircle v-else class="w-3 h-3" />
            <span>{{ isValidJson ? (validationResult.isNull ? 'Empty / NULL' : 'Valid JSON') : 'Invalid JSON' }}</span>
          </div>
        </div>
      </div>

      <!-- Main Body Area -->
      <div class="flex-1 overflow-hidden relative bg-slate-950 flex flex-col">
        <!-- 1. Code Editor Mode -->
        <div v-show="activeMode === 'code'" class="flex-1 flex overflow-hidden relative bg-slate-950">
          <!-- Line Numbers Gutter -->
          <div
            ref="lineNumbersRef"
            class="w-12 bg-slate-950 border-r border-slate-850 py-3 text-right pr-3 font-mono text-xs text-slate-600 select-none overflow-hidden shrink-0 leading-relaxed font-medium"
          >
            <div v-for="n in linesCount" :key="n">{{ n }}</div>
          </div>

          <!-- Editor Container with Synced Highlight Layer -->
          <div class="flex-1 relative overflow-hidden bg-slate-950">
            <!-- Background Syntax Highlight Layer -->
            <pre
              ref="preRef"
              class="absolute inset-0 p-3 font-mono text-xs leading-relaxed whitespace-pre-wrap break-words pointer-events-none overflow-hidden select-none text-slate-100 m-0 bg-transparent border-0 font-normal"
            ><code v-html="highlightedJson"></code></pre>

            <!-- Foreground Transparent Textarea -->
            <textarea
              ref="textareaRef"
              v-model="editorContent"
              @scroll="handleEditorScroll"
              placeholder="{ ... }"
              spellcheck="false"
              autocapitalize="off"
              autocomplete="off"
              autocorrect="off"
              class="sql-editor-input absolute inset-0 p-3 font-mono text-xs leading-relaxed whitespace-pre-wrap break-words bg-transparent text-transparent caret-emerald-400 dark:caret-matcha-400 focus:outline-none resize-none overflow-auto selection:bg-emerald-500/25 selection:text-transparent placeholder:text-slate-700 border-0 m-0"
            ></textarea>
          </div>
        </div>

        <!-- 2. Interactive Tree View Mode -->
        <div
          v-show="activeMode === 'tree'"
          class="flex-1 overflow-auto p-4 bg-slate-950 font-mono text-xs"
        >
          <template v-if="isValidJson && parsedJsonObject !== null && typeof parsedJsonObject === 'object'">
            <JsonTreeNode
              :value="parsedJsonObject"
              path=""
              :depth="0"
              :search-query="treeSearchQuery"
              :is-editable="false"
              :force-expand="forceExpand"
              @copy-path="handleTreeCopyPath"
            />
          </template>
          <div v-else class="h-full flex flex-col items-center justify-center text-slate-500 text-xs">
            <p>Tree view is available for valid JSON objects and arrays.</p>
          </div>
        </div>

        <!-- Bottom Syntax Error Warning Bar if invalid -->
        <div
          v-if="!isValidJson && validationResult.error"
          class="h-8 px-4 bg-rose-950/70 border-t border-rose-900/60 text-rose-300 font-mono text-[11px] flex items-center justify-between shrink-0"
        >
          <div class="flex items-center gap-2 truncate">
            <AlertCircle class="w-3.5 h-3.5 text-rose-400 shrink-0" />
            <span class="truncate">{{ validationResult.error }}</span>
          </div>
          <span v-if="validationResult.line" class="text-rose-400 font-semibold shrink-0 ml-2">
            Pos/Line: {{ validationResult.line }}
          </span>
        </div>
      </div>

      <!-- Bottom Footer Toolbar -->
      <div class="px-5 py-3 bg-slate-900/90 border-t border-slate-800 flex items-center justify-between shrink-0 text-xs">
        <div class="flex items-center gap-3 text-slate-400 font-mono text-[11px]">
          <span>{{ linesCount }} lines</span>
          <span class="text-slate-600">•</span>
          <span>{{ characterCount }} chars</span>
        </div>

        <button
          @click="emit('close')"
          class="px-4 py-1.5 rounded-lg border border-slate-700 bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white transition text-xs font-medium"
        >
          Close
        </button>
      </div>
    </div>
  </div>
</template>
