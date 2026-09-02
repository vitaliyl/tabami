<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { router } from '@inertiajs/vue3';
import {
  Database,
  Table as TableIcon,
  Eye,
  Plus,
  Search,
  RefreshCw,
  Terminal,
  ChevronDown,
  ChevronRight,
  Layers,
  Trash2,
  CalendarDays,
  CreditCard,
  Bot,
  ShieldCheck,
  Plug,
  ShoppingBag,
  History,
  LayoutGrid,
  ListFilter,
  Gem,
  Sun,
  Moon
} from 'lucide-vue-next';
import type { DomainGroup, TableItem } from '../utils/domainClassifier';
import { classifyTablesIntoDomains } from '../utils/domainClassifier';
import { useTheme } from '../utils/useTheme';
import { isTauri } from '../utils/api';
import TabamiLogo from './TabamiLogo.vue';

const { theme, isDark, isMatcha, isLight, themeLabel, nextThemeTitle, toggleTheme } = useTheme();

const DEFAULT_SIDEBAR_WIDTH = 288;
const MIN_SIDEBAR_WIDTH = 200;
const MAX_SIDEBAR_WIDTH = 640;
const STORAGE_KEY = 'tabami_sidebar_width';

const sidebarWidth = ref(DEFAULT_SIDEBAR_WIDTH);
const isResizing = ref(false);

onMounted(() => {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const parsed = parseInt(saved, 10);
      if (!isNaN(parsed) && parsed >= MIN_SIDEBAR_WIDTH && parsed <= MAX_SIDEBAR_WIDTH) {
        sidebarWidth.value = parsed;
      }
    }
  } catch (e) {
    // ignore storage error
  }
});

function startResizing(event: MouseEvent) {
  event.preventDefault();
  isResizing.value = true;
  document.body.style.cursor = 'col-resize';
  document.body.style.userSelect = 'none';

  const startX = event.clientX;
  const startWidth = sidebarWidth.value;

  function onMouseMove(e: MouseEvent) {
    const delta = e.clientX - startX;
    const maxAllowed = Math.min(MAX_SIDEBAR_WIDTH, Math.max(MIN_SIDEBAR_WIDTH, window.innerWidth * 0.6));
    const newWidth = Math.min(
      Math.max(startWidth + delta, MIN_SIDEBAR_WIDTH),
      maxAllowed
    );
    sidebarWidth.value = newWidth;
  }

  function onMouseUp() {
    isResizing.value = false;
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    try {
      localStorage.setItem(STORAGE_KEY, sidebarWidth.value.toString());
    } catch (e) {}
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  }

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
}

function resetWidth() {
  sidebarWidth.value = DEFAULT_SIDEBAR_WIDTH;
  try {
    localStorage.setItem(STORAGE_KEY, sidebarWidth.value.toString());
  } catch (e) {}
}

interface Connection {
  id: string;
  name: string;
  adapter: string;
  is_demo?: boolean;
  database?: string;
  host?: string;
  file_path?: string;
}

const props = defineProps<{
  connections: Connection[];
  activeConnection: Connection | null;
  schemas: string[];
  selectedSchema: string;
  tables: TableItem[];
  selectedTable?: string;
  activeTab: string;
  selectedDomain?: string | null;
}>();

const emit = defineEmits<{
  (e: 'open-connection-modal'): void;
  (e: 'select-connection', connId: string): void;
  (e: 'delete-connection', connId: string): void;
  (e: 'select-table', table: string): void;
  (e: 'select-schema', schema: string): void;
  (e: 'refresh-data'): void;
  (e: 'select-tab', tab: 'structure' | 'query' | 'domains'): void;
  (e: 'select-domain', domainId: string | null): void;
}>();

const searchQuery = ref('');
const searchInputRef = ref<HTMLInputElement | null>(null);
const connectionDropdownOpen = ref(false);
const isRefreshing = ref(false);
const viewMode = ref<'grouped' | 'flat'>('grouped');

function focusSearch() {
  searchInputRef.value?.focus();
  searchInputRef.value?.select();
}

defineExpose({
  focusSearch,
});

// Track expanded domain groups
const expandedGroups = ref<Record<string, boolean>>({});

const iconMap: Record<string, any> = {
  CalendarDays,
  CreditCard,
  Bot,
  ShieldCheck,
  Plug,
  ShoppingBag,
  History,
  Layers,
  Database,
};

function getDomainIcon(name: string) {
  return iconMap[name] || Database;
}

// Compute classified domain groups
const domainGroups = computed(() => {
  return classifyTablesIntoDomains(props.tables);
});

// Initialize all domain groups as expanded
watch(
  domainGroups,
  (groups) => {
    groups.forEach((g) => {
      if (expandedGroups.value[g.id] === undefined) {
        expandedGroups.value[g.id] = true;
      }
    });
  },
  { immediate: true }
);

// Auto-expand groups when user searches
watch(searchQuery, (query) => {
  if (query.trim()) {
    domainGroups.value.forEach((g) => {
      expandedGroups.value[g.id] = true;
    });
  }
});

function toggleGroup(groupId: string, event: Event) {
  event.stopPropagation();
  expandedGroups.value[groupId] = !expandedGroups.value[groupId];
}

const filteredDomainGroups = computed(() => {
  if (!searchQuery.value.trim()) return domainGroups.value;
  const q = searchQuery.value.toLowerCase().trim();

  return domainGroups.value
    .map((group) => {
      const matchesGroup =
        group.name.toLowerCase().includes(q) ||
        group.id.toLowerCase().includes(q);
      const matchingTables = group.tables.filter((t) =>
        t.name.toLowerCase().includes(q)
      );

      if (matchesGroup || matchingTables.length > 0) {
        return {
          ...group,
          tables: matchingTables.length > 0 ? matchingTables : group.tables,
        };
      }
      return null;
    })
    .filter(Boolean) as DomainGroup[];
});

const filteredTables = computed(() => {
  if (!searchQuery.value.trim()) return props.tables;
  const q = searchQuery.value.toLowerCase().trim();
  return props.tables.filter((t) => t.name.toLowerCase().includes(q));
});

function selectConnection(connId: string) {
  connectionDropdownOpen.value = false;
  if (isTauri()) {
    emit('select-connection', connId);
  } else {
    router.post(`/connections/${connId}/select`, {}, {
      preserveState: false,
      preserveScroll: true,
    });
  }
}

function deleteConnection(connId: string, event: Event) {
  event.stopPropagation();
  if (confirm('Are you sure you want to delete this connection?')) {
    if (isTauri()) {
      emit('delete-connection', connId);
    } else {
      router.delete(`/connections/${connId}`, {
        preserveState: false,
        preserveScroll: true,
      });
    }
  }
}

function selectSchema(schema: string) {
  emit('select-schema', schema);
  if (!isTauri()) {
    router.get('/', {
      connection_id: props.activeConnection?.id,
      schema: schema,
    }, {
      preserveState: true,
      preserveScroll: true,
    });
  }
}

function refreshAll(schema?: string) {
  if (isRefreshing.value) return;
  isRefreshing.value = true;
  const targetSchema = schema || props.selectedSchema;
  emit('select-schema', targetSchema);

  if (isTauri()) {
    emit('refresh-data');
    setTimeout(() => {
      isRefreshing.value = false;
    }, 400);
  } else {
    router.get('/', {
      connection_id: props.activeConnection?.id,
      schema: targetSchema,
      refresh: '1',
    }, {
      preserveState: true,
      preserveScroll: true,
      onFinish: () => {
        isRefreshing.value = false;
      }
    });
  }
}

function selectTable(table: TableItem) {
  emit('select-table', table.name);
  if (!isTauri()) {
    router.get('/', {
      connection_id: props.activeConnection?.id,
      schema: props.selectedSchema,
      table: table.name,
      tab: 'structure',
    }, {
      preserveState: true,
      preserveScroll: true,
    });
  }
}

function openDomainsOverview() {
  emit('select-domain', null);
  emit('select-tab', 'domains');
}

function formatRowCount(count?: number) {
  if (count === undefined || count === null) return '';
  if (count >= 1000000) return `${(count / 1000000).toFixed(1)}M`;
  if (count >= 1000) return `${(count / 1000).toFixed(1)}k`;
  return String(count);
}
</script>

<template>
  <aside
    :style="{ width: `${sidebarWidth}px` }"
    :class="[
      'bg-sumi-900 border-r border-sumi-750 flex flex-col h-full select-none shrink-0 relative group/sidebar',
      isResizing ? 'transition-none' : 'transition-[width] duration-75'
    ]"
  >
    <!-- App Brand & Identity -->
    <div class="h-14 px-4 border-b border-sumi-750 flex items-center justify-between bg-sumi-950/50">
      <div class="flex items-center gap-2.5">
        <TabamiLogo class-name="w-8 h-8 rounded-xl shadow-md shadow-sumi-950/60 border border-sumi-700/50 shrink-0" />
        <div>
          <div class="flex items-center gap-1.5">
            <h1 class="text-sm font-bold text-sumi-50 dark:text-white tracking-tight leading-none">Tabami</h1>
            <span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-ruby-950 text-ruby-300 border border-ruby-800/80 tracking-wider">
              STUDIO
            </span>
          </div>
          <span class="text-[10px] text-sumi-400 font-medium">Database Studio</span>
        </div>
      </div>

      <div class="flex items-center gap-1">
        <!-- Theme Switcher Button -->
        <button
          @click="toggleTheme"
          class="p-1.5 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-sumi-300 dark:text-slate-300 hover:text-sumi-50 dark:hover:text-white border border-sumi-700 hover:border-sumi-600 transition"
          :title="nextThemeTitle"
        >
          <Moon v-if="theme === 'dark'" class="w-4 h-4 text-aizome-400" />
          <svg v-else-if="theme === 'matcha'" class="w-4 h-4 text-emerald-700 dark:text-matcha-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor" stroke="none" />
          </svg>
          <Sun v-else class="w-4 h-4 text-yamabuki-400" />
        </button>

        <button
          @click="emit('open-connection-modal')"
          class="p-1.5 rounded-lg bg-sumi-850 hover:bg-sumi-800 text-sumi-300 dark:text-slate-300 hover:text-sumi-50 dark:hover:text-white border border-sumi-700 hover:border-ruby-500/40 transition"
          title="Add Connection"
        >
          <Plus class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Active Connection Selector -->
    <div class="p-3 border-b border-sumi-750 relative">
      <label class="block text-[10px] font-semibold uppercase tracking-wider text-sumi-400 mb-1.5">
        Active Connection
      </label>

      <button
        type="button"
        @click="connectionDropdownOpen = !connectionDropdownOpen"
        class="w-full flex items-center justify-between p-2 rounded-xl bg-sumi-950 border border-sumi-750 hover:border-sumi-600 transition text-left"
      >
        <div class="flex items-center gap-2 overflow-hidden">
          <div class="w-2 h-2 rounded-full bg-matcha-500 shadow-[0_0_8px_rgba(16,185,129,0.8)] shrink-0"></div>
          <div class="truncate">
            <p class="text-xs font-semibold text-sumi-50 dark:text-white truncate">
              {{ activeConnection?.name || 'No Connection' }}
            </p>
            <p class="text-[10px] text-sumi-400 uppercase tracking-wider">
              {{ activeConnection?.adapter }} {{ activeConnection?.database ? `• ${activeConnection.database}` : '' }}
            </p>
          </div>
        </div>
        <ChevronDown class="w-4 h-4 text-sumi-400 shrink-0" />
      </button>

      <!-- Connection Dropdown Menu -->
      <div
        v-if="connectionDropdownOpen"
        class="absolute left-3 right-3 top-full mt-1 bg-sumi-900 border border-sumi-700 rounded-xl shadow-2xl z-30 py-1 max-h-60 overflow-y-auto backdrop-blur-md"
      >
        <div
          v-for="conn in connections"
          :key="conn.id"
          @click="selectConnection(conn.id)"
          class="px-3 py-2 hover:bg-sumi-800 cursor-pointer flex items-center justify-between group transition"
        >
          <div class="truncate">
            <p :class="['text-xs font-medium truncate', conn.id === activeConnection?.id ? 'text-ruby-400 font-semibold' : 'text-slate-200']">
              {{ conn.name }}
            </p>
            <p class="text-[10px] text-sumi-400 uppercase">{{ conn.adapter }}</p>
          </div>
          <button
            v-if="!conn.is_demo"
            @click="deleteConnection(conn.id, $event)"
            class="opacity-0 group-hover:opacity-100 p-1 text-sumi-400 hover:text-ruby-400 hover:bg-sumi-700 rounded transition"
            title="Delete Connection"
          >
            <Trash2 class="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </div>

    <!-- Quick Tools: Domains Overview & SQL Console -->
    <div class="p-3 border-b border-sumi-750 space-y-1.5">
      <div class="flex items-center gap-1.5">
        <button
          @click="openDomainsOverview"
          :class="[
            'flex-1 flex items-center justify-center gap-1.5 py-1.5 px-2.5 rounded-xl text-xs font-semibold transition border',
            activeTab === 'domains' && !selectedDomain
              ? 'bg-sumi-800 text-sumi-50 dark:text-white border-sumi-650 shadow-sm ring-1 ring-sumi-750/30'
              : 'bg-sumi-850 text-sumi-300 dark:text-slate-300 border-sumi-750 hover:bg-sumi-800 hover:text-sumi-50 dark:hover:text-white'
          ]"
          title="Browse all schema domains"
        >
          <LayoutGrid class="w-3.5 h-3.5 text-aizome-400" />
          <span>Domains</span>
        </button>

        <button
          @click="refreshAll()"
          :disabled="isRefreshing"
          class="p-1.5 rounded-xl bg-sumi-850 hover:bg-sumi-800 text-sumi-400 hover:text-sumi-50 dark:hover:text-white border border-sumi-750 transition shrink-0 disabled:opacity-60"
          title="Refresh schemas and tables"
        >
          <RefreshCw :class="['w-3.5 h-3.5', isRefreshing && 'animate-spin text-aizome-400']" />
        </button>
      </div>

      <button
        @click="emit('select-tab', 'query')"
        :class="[
          'w-full flex items-center justify-center gap-1.5 py-1.5 px-3 rounded-xl text-xs font-semibold transition border',
          activeTab === 'query'
            ? 'bg-sumi-800 text-sumi-50 dark:text-white border-sumi-650 shadow-sm ring-1 ring-sumi-750/30'
            : 'bg-sumi-850 text-sumi-300 dark:text-slate-300 border-sumi-750 hover:bg-sumi-800 hover:text-sumi-50 dark:hover:text-white'
        ]"
      >
        <Terminal class="w-3.5 h-3.5 text-matcha-400" />
        <span>SQL Console</span>
      </button>
    </div>

    <!-- Schema Selector (If multiple schemas exist) -->
    <div v-if="schemas.length > 1" class="px-3 pt-3">
      <div class="flex items-center justify-between mb-1">
        <label class="text-[10px] font-semibold uppercase tracking-wider text-sumi-400 flex items-center gap-1">
          <Layers class="w-3 h-3 text-sumi-400" />
          Schema
        </label>
      </div>
      <select
        :value="selectedSchema"
        @change="selectSchema(($event.target as HTMLSelectElement).value)"
        class="w-full bg-sumi-950 border border-sumi-750 text-xs text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-sumi-500"
      >
        <option v-for="sch in schemas" :key="sch" :value="sch">{{ sch }}</option>
      </select>
    </div>

    <!-- Search & View Mode Switcher -->
    <div class="p-3 pb-2 space-y-2">
      <div class="flex items-center justify-between">
        <span class="text-[10px] font-semibold uppercase tracking-wider text-sumi-400 flex items-center gap-1">
          <Layers class="w-3 h-3 text-aizome-400" />
          {{ viewMode === 'grouped' ? 'Schema Domains' : 'All Tables (A-Z)' }}
        </span>

        <div class="flex items-center bg-sumi-950 border border-sumi-750 rounded-lg p-0.5">
          <button
            @click="viewMode = 'grouped'"
            :class="[
              'px-2 py-0.5 rounded-md text-[10px] font-semibold transition flex items-center gap-1',
              viewMode === 'grouped'
                ? 'bg-sumi-800 text-sumi-50 dark:text-white shadow-xs border border-sumi-650 font-bold'
                : 'text-sumi-400 hover:text-sumi-200'
            ]"
            title="Grouped by domain"
          >
            <LayoutGrid class="w-3 h-3" />
            <span>Groups</span>
          </button>
          <button
            @click="viewMode = 'flat'"
            :class="[
              'px-2 py-0.5 rounded-md text-[10px] font-semibold transition flex items-center gap-1',
              viewMode === 'flat'
                ? 'bg-sumi-800 text-sumi-50 dark:text-white shadow-xs border border-sumi-650 font-bold'
                : 'text-sumi-400 hover:text-sumi-200'
            ]"
            title="Flat list A-Z"
          >
            <ListFilter class="w-3 h-3" />
            <span>Flat</span>
          </button>
        </div>
      </div>

      <div class="relative">
        <Search class="w-3.5 h-3.5 text-sumi-400 absolute left-2.5 top-1/2 -translate-y-1/2" />
        <input
          ref="searchInputRef"
          v-model="searchQuery"
          type="text"
          :placeholder="viewMode === 'grouped' ? 'Filter domains & tables...' : 'Filter tables & views...'"
          class="w-full bg-sumi-950 border border-sumi-750 rounded-xl pl-8 pr-3 py-1.5 text-xs text-white placeholder-sumi-500 focus:outline-none focus:border-sumi-500 focus:ring-1 focus:ring-aizome-500/30 transition"
        />
      </div>
    </div>

    <!-- Foldable Domain Groups View -->
    <div v-if="viewMode === 'grouped'" class="flex-1 overflow-y-auto px-2 pb-4 space-y-1.5">
      <div v-if="filteredDomainGroups.length === 0" class="text-center py-8 text-xs text-sumi-400">
        No matching domains or tables
      </div>

      <div
        v-for="group in filteredDomainGroups"
        :key="group.id"
        class="border border-sumi-750 rounded-xl overflow-hidden bg-sumi-950/40"
      >
        <button
          @click="toggleGroup(group.id, $event)"
          class="w-full flex items-center justify-between px-2.5 py-2 hover:bg-sumi-850/60 transition text-left group/hdr"
        >
          <div class="flex items-center gap-2 truncate">
            <component
              :is="getDomainIcon(group.iconName)"
              :class="['w-3.5 h-3.5 shrink-0', group.color.accent]"
            />
            <span class="text-xs font-semibold text-sumi-100 group-hover/hdr:text-sumi-50 dark:text-slate-200 dark:group-hover/hdr:text-white truncate">
              {{ group.name }}
            </span>
          </div>

          <div class="flex items-center gap-1.5 shrink-0">
            <span
              :class="[
                'text-[10px] font-mono px-1.5 py-0.2 rounded border font-semibold',
                group.color.badge
              ]"
            >
              {{ group.tables.length }}
            </span>
            <ChevronDown
              :class="[
                'w-3.5 h-3.5 text-sumi-400 transition-transform duration-200',
                !expandedGroups[group.id] && '-rotate-90'
              ]"
            />
          </div>
        </button>

        <div v-show="expandedGroups[group.id]" class="px-1 pb-1 pt-0.5 space-y-0.5 border-t border-sumi-800">
          <button
            v-for="table in group.tables"
            :key="table.name"
            @click="selectTable(table)"
            :class="[
              'w-full flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs font-mono transition group text-left active-table-item',
              selectedTable === table.name && activeTab !== 'query' && activeTab !== 'domains'
                ? 'bg-indigo-50 dark:bg-aizome-500/20 text-indigo-700 dark:text-aizome-300 border-l-2 border-indigo-600 dark:border-aizome-500 font-bold shadow-xs is-selected-table'
                : 'text-sumi-200 hover:bg-sumi-850 hover:text-sumi-50 dark:hover:text-white border-l-2 border-transparent'
            ]"
          >
            <div class="flex items-center gap-2 truncate pl-1">
              <TableIcon v-if="table.type === 'table'" :class="['w-3 h-3 shrink-0 table-icon', selectedTable === table.name ? 'text-indigo-600 dark:text-aizome-400 is-selected-icon' : 'text-sumi-400 group-hover:text-indigo-600 dark:group-hover:text-aizome-300']" />
              <Eye v-else :class="['w-3 h-3 shrink-0 table-icon', selectedTable === table.name ? 'text-indigo-600 dark:text-aizome-400 is-selected-icon' : 'text-sumi-400 group-hover:text-indigo-600 dark:group-hover:text-aizome-300']" />
              <span class="truncate table-name-text">{{ table.name }}</span>
            </div>

            <span
              v-if="table.estimated_rows !== undefined && table.estimated_rows !== null"
              class="text-[10px] text-sumi-300 font-mono bg-sumi-850 px-1.5 py-0.2 rounded border border-sumi-750 shrink-0 font-medium"
            >
              {{ formatRowCount(table.estimated_rows) }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <!-- Flat List View -->
    <div v-else class="flex-1 overflow-y-auto px-2 pb-4 space-y-0.5">
      <div v-if="filteredTables.length === 0" class="text-center py-8 text-xs text-sumi-400">
        No tables found
      </div>

      <button
        v-for="table in filteredTables"
        :key="table.name"
        @click="selectTable(table)"
        :class="[
          'w-full flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs font-mono transition group text-left active-table-item',
          selectedTable === table.name && activeTab !== 'query' && activeTab !== 'domains'
            ? 'bg-indigo-50 dark:bg-aizome-500/20 text-indigo-700 dark:text-aizome-300 border-l-2 border-indigo-600 dark:border-aizome-500 font-bold shadow-xs is-selected-table'
            : 'text-sumi-200 hover:bg-sumi-850 hover:text-sumi-50 dark:hover:text-white border-l-2 border-transparent'
        ]"
      >
        <div class="flex items-center gap-2 truncate">
          <TableIcon v-if="table.type === 'table'" :class="['w-3.5 h-3.5 shrink-0 table-icon', selectedTable === table.name ? 'text-indigo-600 dark:text-aizome-400 is-selected-icon' : 'text-sumi-400 group-hover:text-indigo-600 dark:group-hover:text-aizome-300']" />
          <Eye v-else :class="['w-3.5 h-3.5 shrink-0 table-icon', selectedTable === table.name ? 'text-indigo-600 dark:text-aizome-400 is-selected-icon' : 'text-sumi-400 group-hover:text-indigo-600 dark:group-hover:text-aizome-300']" />
          <span class="truncate table-name-text">{{ table.name }}</span>
        </div>

        <span
          v-if="table.estimated_rows !== undefined && table.estimated_rows !== null"
          class="text-[10px] text-sumi-300 font-mono bg-sumi-850 px-1.5 py-0.5 rounded border border-sumi-750 shrink-0 font-medium"
        >
          {{ formatRowCount(table.estimated_rows) }}
        </span>
      </button>
    </div>

    <!-- Sidebar Footer -->
    <div class="p-2.5 border-t border-sumi-750 bg-sumi-950/60 shrink-0 flex items-center justify-between">
      <button
        @click="toggleTheme"
        class="w-full flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-xl bg-sumi-850 hover:bg-sumi-800 text-sumi-300 dark:text-slate-300 hover:text-sumi-50 dark:hover:text-white border border-sumi-750 text-xs font-semibold transition"
        :title="nextThemeTitle"
      >
        <Moon v-if="theme === 'dark'" class="w-3.5 h-3.5 text-aizome-400" />
        <svg v-else-if="theme === 'matcha'" class="w-3.5 h-3.5 text-emerald-700 dark:text-matcha-400 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="9" />
          <path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor" stroke="none" />
        </svg>
        <Sun v-else class="w-3.5 h-3.5 text-yamabuki-400" />
        <span class="truncate">{{ themeLabel }}</span>
      </button>
    </div>

    <!-- Resize Handle -->
    <div
      @mousedown="startResizing"
      @dblclick="resetWidth"
      title="Drag to resize, double-click to reset"
      class="absolute top-0 -right-1.5 bottom-0 w-3 cursor-col-resize z-30 group/resizer flex items-center justify-center select-none"
    >
      <div
        :class="[
          'w-0.5 h-full transition-colors duration-150',
          isResizing
            ? 'bg-ruby-500 shadow-[0_0_10px_rgba(225,29,72,0.8)]'
            : 'bg-transparent group-hover/resizer:bg-ruby-500/60'
        ]"
      />
    </div>
  </aside>
</template>
