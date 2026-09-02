<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import {
  ChevronRight,
  ChevronDown,
  Copy,
  Check,
  Edit2,
  Check as CheckIcon,
  X as CancelIcon
} from 'lucide-vue-next';
import { applySearchHighlight, escapeHtml } from '../utils/jsonHighlighter';

const props = withDefaults(
  defineProps<{
    nodeKey?: string | number;
    value: any;
    path: string;
    depth?: number;
    searchQuery?: string;
    isEditable?: boolean;
    forceExpand?: boolean | null;
  }>(),
  {
    depth: 0,
    searchQuery: '',
    isEditable: false,
    forceExpand: null,
  }
);

const emit = defineEmits<{
  (e: 'update-value', payload: { path: string; value: any }): void;
  (e: 'copy-path', path: string): void;
}>();

const isExpanded = ref(props.depth < 2);
const isEditing = ref(false);
const editValue = ref('');
const copiedPath = ref(false);

watch(
  () => props.forceExpand,
  (val) => {
    if (val !== null && val !== undefined) {
      isExpanded.value = val;
    }
  }
);

const valueType = computed(() => {
  if (props.value === null) return 'null';
  if (props.value === undefined) return 'undefined';
  if (Array.isArray(props.value)) return 'array';
  return typeof props.value;
});

const isContainer = computed(() => {
  return valueType.value === 'object' || valueType.value === 'array';
});

const childEntries = computed(() => {
  if (valueType.value === 'object' && props.value !== null) {
    return Object.entries(props.value);
  }
  if (valueType.value === 'array') {
    return (props.value as any[]).map((item, idx) => [idx, item] as [number, any]);
  }
  return [];
});

const matchesSearch = computed(() => {
  if (!props.searchQuery) return true;
  const q = props.searchQuery.toLowerCase();
  const keyMatch = props.nodeKey !== undefined && String(props.nodeKey).toLowerCase().includes(q);
  const valMatch = !isContainer.value && String(props.value).toLowerCase().includes(q);
  return keyMatch || valMatch;
});

const highlightedKey = computed(() => {
  if (props.nodeKey === undefined) return '';
  return applySearchHighlight(escapeHtml(String(props.nodeKey)), props.searchQuery);
});

const highlightedValue = computed(() => {
  if (props.value === null) return 'null';
  if (props.value === undefined) return 'undefined';
  return applySearchHighlight(escapeHtml(String(props.value)), props.searchQuery);
});

function toggleExpand() {
  if (isContainer.value) {
    isExpanded.value = !isExpanded.value;
  }
}

function handleCopyPath() {
  emit('copy-path', props.path);
  copiedPath.value = true;
  setTimeout(() => (copiedPath.value = false), 1500);
}

function startEdit() {
  if (!props.isEditable || isContainer.value) return;
  editValue.value = valueType.value === 'string' ? props.value : JSON.stringify(props.value);
  isEditing.value = true;
}

function saveEdit() {
  let parsed: any = editValue.value;
  if (valueType.value === 'number') {
    const num = Number(editValue.value);
    parsed = isNaN(num) ? editValue.value : num;
  } else if (valueType.value === 'boolean') {
    parsed = editValue.value === 'true';
  } else if (valueType.value === 'null' || editValue.value === 'null') {
    parsed = null;
  } else if (valueType.value !== 'string') {
    try {
      parsed = JSON.parse(editValue.value);
    } catch {
      parsed = editValue.value;
    }
  }

  emit('update-value', { path: props.path, value: parsed });
  isEditing.value = false;
}

function cancelEdit() {
  isEditing.value = false;
}

function getChildPath(key: string | number): string {
  if (!props.path) {
    return typeof key === 'number' ? `[${key}]` : String(key);
  }
  return typeof key === 'number' ? `${props.path}[${key}]` : `${props.path}.${key}`;
}
</script>

<template>
  <div
    class="font-mono text-xs select-text leading-relaxed"
    :class="[
      !matchesSearch && searchQuery ? 'opacity-30' : 'opacity-100',
    ]"
    :style="{ paddingLeft: depth > 0 ? `${depth * 14}px` : '0px' }"
  >
    <div
      class="flex items-center gap-1.5 py-1 px-1.5 rounded-lg hover:bg-slate-850/80 group/node transition-colors"
    >
      <button
        v-if="isContainer"
        @click="toggleExpand"
        class="w-4 h-4 flex items-center justify-center text-slate-500 hover:text-slate-200 transition shrink-0"
      >
        <ChevronDown v-if="isExpanded" class="w-3.5 h-3.5" />
        <ChevronRight v-else class="w-3.5 h-3.5" />
      </button>
      <div v-else class="w-4 shrink-0"></div>

      <span
        v-if="nodeKey !== undefined"
        class="shrink-0 cursor-pointer flex items-center"
        @click="toggleExpand"
      >
        <span v-if="typeof nodeKey === 'number'" class="text-slate-500 font-mono">
          [{{ nodeKey }}]<span class="text-slate-400 dark:text-sumi-500 font-normal ml-0.5 mr-1.5">:</span>
        </span>
        <span v-else class="text-indigo-600 dark:text-indigo-300 font-semibold">
          "<span v-html="highlightedKey"></span>"<span class="text-slate-400 dark:text-sumi-500 font-normal mr-1.5">:</span>
        </span>
      </span>

      <template v-if="isContainer && !isExpanded">
        <span
          @click="toggleExpand"
          class="cursor-pointer text-slate-400 hover:text-slate-200 text-[11px] flex items-center gap-1.5 bg-slate-900/90 px-2 py-0.5 rounded-md border border-slate-800/80 hover:border-slate-700 transition shadow-sm"
        >
          <span v-if="valueType === 'object'" class="text-amber-600 dark:text-amber-400 font-bold">{ ... }</span>
          <span v-else class="text-cyan-600 dark:text-cyan-400 font-bold">[ ... ]</span>
          <span class="text-slate-400 font-mono text-[10px]">{{ childEntries.length }} {{ valueType === 'object' ? 'keys' : 'items' }}</span>
        </span>
      </template>

      <template v-else-if="isContainer && isExpanded">
        <span class="text-slate-500 text-[11px]">
          <span v-if="valueType === 'object'" class="text-amber-600 dark:text-amber-400 font-bold">{</span>
          <span v-else class="text-cyan-600 dark:text-cyan-400 font-bold">[</span>
          <span class="text-slate-500 text-[10px] ml-1">({{ childEntries.length }})</span>
        </span>
      </template>

      <template v-else>
        <div v-if="isEditing" class="flex items-center gap-1 z-10">
          <input
            v-model="editValue"
            @keydown.enter="saveEdit"
            @keydown.esc="cancelEdit"
            type="text"
            autofocus
            class="bg-slate-950 border border-emerald-500 rounded px-1.5 py-0.5 text-xs text-white font-mono focus:outline-none min-w-[120px]"
          />
          <button
            @click="saveEdit"
            class="p-0.5 rounded bg-emerald-600 hover:bg-emerald-500 text-white"
            title="Save (Enter)"
          >
            <CheckIcon class="w-3 h-3" />
          </button>
          <button
            @click="cancelEdit"
            class="p-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-400"
            title="Cancel (Esc)"
          >
            <CancelIcon class="w-3 h-3" />
          </button>
        </div>

        <div v-else class="flex items-center gap-2 truncate">
          <span
            v-if="valueType === 'string'"
            class="text-emerald-700 dark:text-emerald-300 truncate cursor-pointer hover:underline"
            @dblclick="startEdit"
            title="Double-click to edit"
          >
            "<span v-html="highlightedValue"></span>"
          </span>

          <span
            v-else-if="valueType === 'number'"
            class="text-amber-600 dark:text-yamabuki-400 font-mono font-medium cursor-pointer hover:underline"
            @dblclick="startEdit"
            title="Double-click to edit"
            v-html="highlightedValue"
          ></span>

          <span
            v-else-if="valueType === 'boolean'"
            :class="[
              'px-1.5 py-0.2 rounded text-[10px] font-bold uppercase tracking-wider cursor-pointer hover:opacity-80 transition',
              value
                ? 'bg-emerald-500/10 text-emerald-600 dark:text-matcha-400 border border-emerald-500/30'
                : 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/30'
            ]"
            @dblclick="startEdit"
            title="Double-click to edit"
          >
            {{ value ? 'true' : 'false' }}
          </span>

          <span
            v-else-if="valueType === 'null'"
            class="text-slate-500 dark:text-slate-400 italic font-semibold text-[11px] cursor-pointer hover:underline"
            @dblclick="startEdit"
            title="Double-click to edit"
          >
            null
          </span>

          <span v-else class="text-slate-400" @dblclick="startEdit" v-html="highlightedValue"></span>

          <span
            :class="[
              'text-[9px] px-1 py-0.2 rounded font-mono uppercase tracking-wider shrink-0 border',
              valueType === 'string' ? 'text-emerald-500/90 bg-emerald-950/40 border-emerald-800/40' :
              valueType === 'number' ? 'text-amber-500/90 bg-amber-950/40 border-amber-800/40' :
              valueType === 'boolean' ? 'text-indigo-400 bg-indigo-950/40 border-indigo-800/40' :
              'text-slate-500 bg-slate-900 border-slate-800'
            ]"
          >
            {{ valueType === 'string' ? 'str' : valueType === 'number' ? 'num' : valueType === 'boolean' ? 'bool' : valueType }}
          </span>
        </div>
      </template>

      <div class="ml-auto opacity-0 group-hover/node:opacity-100 flex items-center gap-1 shrink-0 transition">
        <button
          v-if="isEditable && !isContainer && !isEditing"
          @click="startEdit"
          class="p-1 rounded text-slate-500 hover:text-emerald-400 hover:bg-slate-800 transition"
          title="Edit Value"
        >
          <Edit2 class="w-3 h-3" />
        </button>

        <button
          @click="handleCopyPath"
          class="p-1 rounded text-slate-500 hover:text-white hover:bg-slate-800 transition flex items-center gap-0.5"
          :title="`Copy path: ${path || 'root'}`"
        >
          <Check v-if="copiedPath" class="w-3 h-3 text-emerald-400" />
          <Copy v-else class="w-3 h-3" />
        </button>
      </div>
    </div>

    <div v-if="isContainer && isExpanded" class="flex flex-col border-l border-slate-800/80 hover:border-slate-700 ml-2.5 transition-colors">
      <JsonTreeNode
        v-for="[cKey, cVal] in childEntries"
        :key="cKey"
        :node-key="cKey"
        :value="cVal"
        :path="getChildPath(cKey)"
        :depth="depth + 1"
        :search-query="searchQuery"
        :is-editable="isEditable"
        :force-expand="forceExpand"
        @update-value="(payload) => emit('update-value', payload)"
        @copy-path="(p) => emit('copy-path', p)"
      />

      <div
        class="text-slate-500 text-[11px] py-0.5 px-1.5"
        :style="{ paddingLeft: depth > 0 ? `${(depth + 1) * 14}px` : '14px' }"
      >
        <span v-if="valueType === 'object'" class="text-amber-600 dark:text-amber-400 font-bold">}</span>
        <span v-else class="text-cyan-600 dark:text-cyan-400 font-bold">]</span>
      </div>
    </div>
  </div>
</template>
