<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { router } from '@inertiajs/vue3';
import {
  Layers,
  Terminal,
  Database,
  CheckCircle2,
  AlertCircle,
  LayoutGrid,
  Sun,
  Moon
} from 'lucide-vue-next';

import Sidebar from '../components/Sidebar.vue';
import TableStructure from '../components/TableStructure.vue';
import SqlEditor from '../components/SqlEditor.vue';
import DomainOverview from '../components/DomainOverview.vue';
import DomainDetail from '../components/DomainDetail.vue';
import ConnectionModal from '../components/ConnectionModal.vue';
import ValueInspectorModal from '../components/ValueInspectorModal.vue';
import { classifyTablesIntoDomains, type DomainGroup, type TableItem } from '../utils/domainClassifier';
import { useTheme } from '../utils/useTheme';
import {
  isTauri,
  fetchInitialState,
  fetchTableStructure,
  fetchTables,
  deleteConnection,
  type ConnectionConfig
} from '../utils/api';

const { theme, isDark, isMatcha, isLight, nextThemeTitle, toggleTheme } = useTheme();

const props = defineProps<{
  flash?: {
    notice?: string;
    alert?: string;
  };
  connections?: ConnectionConfig[];
  active_connection_id?: string;
  active_connection?: ConnectionConfig | null;
  schemas?: string[];
  selected_schema?: string;
  tables?: TableItem[];
  selected_table?: string;
  table_structure?: any;
  query_tab?: 'structure' | 'query' | 'domains';
}>();

const defaultFallbackConnection: ConnectionConfig = {
  id: 'demo',
  name: 'Demo Database (Standalone)',
  adapter: 'sqlite',
  database: 'demo.sqlite3',
  is_demo: true,
};

const defaultFallbackTables: TableItem[] = [
  { name: 'users', type: 'table', schema: 'main', estimated_rows: 4 },
  { name: 'accounts', type: 'table', schema: 'main', estimated_rows: 3 },
  { name: 'sports_events', type: 'table', schema: 'main', estimated_rows: 2 },
  { name: 'event_members', type: 'table', schema: 'main', estimated_rows: 5 },
  { name: 'ledger_accounts', type: 'table', schema: 'main', estimated_rows: 6 },
  { name: 'ledger_charges', type: 'table', schema: 'main', estimated_rows: 8 },
  { name: 'audit_logs', type: 'table', schema: 'main', estimated_rows: 12 },
];

const backendError = ref<string | null>(null);

const localConnections = ref<ConnectionConfig[]>(
  props.connections && props.connections.length > 0 ? props.connections : [defaultFallbackConnection]
);
const localActiveConnection = ref<ConnectionConfig | null>(
  props.active_connection || props.connections?.[0] || defaultFallbackConnection
);
const localSchemas = ref<string[]>(
  props.schemas && props.schemas.length > 0 ? props.schemas : ['main']
);
const localSelectedSchema = ref<string>(props.selected_schema || 'main');
const localTables = ref<TableItem[]>(
  props.tables && props.tables.length > 0 ? props.tables : defaultFallbackTables
);
const localSelectedTable = ref<string | undefined>(props.selected_table);
const localTableStructure = ref<any>(props.table_structure || null);

const currentTab = ref<'structure' | 'query' | 'domains'>(
  props.query_tab || (props.selected_table ? 'structure' : 'domains')
);
const selectedDomainId = ref<string | null>(null);
const isConnectionModalOpen = ref(false);
const sidebarRef = ref<any>(null);

async function loadTauriState(connId?: string, schema?: string) {
  if (!isTauri()) return;
  try {
    backendError.value = null;
    const data = await fetchInitialState(connId, schema);
    if (data) {
      if (data.connections && data.connections.length > 0) {
        localConnections.value = data.connections;
      }
      if (data.active_connection) {
        localActiveConnection.value = data.active_connection;
      }
      if (data.schemas && data.schemas.length > 0) {
        localSchemas.value = data.schemas;
      }
      if (data.selected_schema) {
        localSelectedSchema.value = data.selected_schema;
      }
      if (data.tables && data.tables.length > 0) {
        localTables.value = data.tables;
      }
    }
  } catch (e: any) {
    console.error('Error loading Tauri state:', e);
    backendError.value = `Backend Notice: ${e?.message || String(e)}`;
  }
}

function handleGlobalKeyDown(e: KeyboardEvent) {
  const target = e.target as HTMLElement;
  const isInput = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable);

  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault();
    sidebarRef.value?.focusSearch();
    return;
  }

  if (isInput) {
    if (e.key === 'Escape') {
      target.blur();
    }
    return;
  }

  if (e.key === '1' || (e.altKey && e.key === '1')) {
    e.preventDefault();
    switchTab('domains');
  } else if ((e.key === '2' || (e.altKey && e.key === '2')) && localSelectedTable.value) {
    e.preventDefault();
    switchTab('structure');
  } else if (e.key === '3' || (e.altKey && e.key === '3')) {
    e.preventDefault();
    switchTab('query');
  } else if (e.key.toLowerCase() === 't') {
    e.preventDefault();
    toggleTheme();
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleGlobalKeyDown);
  if (isTauri()) {
    loadTauriState();
  }
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalKeyDown);
});

const inspectorModal = ref<{ isOpen: boolean; col: string; val: any }>({
  isOpen: false,
  col: '',
  val: null,
});

const domainGroups = computed(() => {
  return classifyTablesIntoDomains(localTables.value);
});

const activeDomain = computed(() => {
  if (!selectedDomainId.value) return null;
  return domainGroups.value.find((d) => d.id === selectedDomainId.value) || null;
});

watch(
  () => props.connections,
  (c) => { if (c && c.length > 0) localConnections.value = c; }
);

watch(
  () => props.active_connection,
  (ac) => { if (ac) localActiveConnection.value = ac; }
);

watch(
  () => props.schemas,
  (s) => { if (s && s.length > 0) localSchemas.value = s; }
);

watch(
  () => props.selected_schema,
  (ss) => { if (ss) localSelectedSchema.value = ss; }
);

watch(
  () => props.tables,
  (t) => { if (t && t.length > 0) localTables.value = t; }
);

watch(
  () => props.selected_table,
  (st) => {
    if (st) {
      localSelectedTable.value = st;
      currentTab.value = 'structure';
    }
  }
);

watch(
  () => props.table_structure,
  (ts) => { if (ts) localTableStructure.value = ts; }
);

function switchTab(tab: 'structure' | 'query' | 'domains') {
  currentTab.value = tab;
}

function handleSelectDomain(domainId: string | null) {
  selectedDomainId.value = domainId;
  currentTab.value = 'domains';
}

async function handleSelectTable(tableName: string) {
  localSelectedTable.value = tableName;
  currentTab.value = 'structure';

  if (isTauri() && localActiveConnection.value) {
    try {
      backendError.value = null;
      const struct = await fetchTableStructure(
        localActiveConnection.value.id,
        tableName,
        localSelectedSchema.value
      );
      localTableStructure.value = struct;
    } catch (err: any) {
      console.error('Failed to load table structure:', err);
      backendError.value = `Table structure error: ${err?.message || String(err)}`;
    }
  } else {
    router.get('/', {
      connection_id: localActiveConnection.value?.id,
      schema: localSelectedSchema.value,
      table: tableName,
      tab: 'structure',
    }, {
      preserveState: true,
      preserveScroll: true,
    });
  }
}

function handleSelectTableFromDomain(table: TableItem, tab: 'structure' = 'structure') {
  handleSelectTable(table.name);
}

async function handleSelectSchema(schema: string) {
  localSelectedSchema.value = schema;
  if (isTauri() && localActiveConnection.value) {
    try {
      backendError.value = null;
      const tables = await fetchTables(localActiveConnection.value.id, schema);
      localTables.value = tables;
    } catch (err: any) {
      console.error('Failed to fetch schema tables:', err);
      backendError.value = `Schema fetch error: ${err?.message || String(err)}`;
    }
  } else {
    router.get('/', {
      connection_id: localActiveConnection.value?.id,
      schema: schema,
    }, {
      preserveState: true,
      preserveScroll: true,
    });
  }
}

async function handleSelectConnection(connId: string) {
  if (isTauri()) {
    await loadTauriState(connId);
  }
}

async function handleDeleteConnection(connId: string) {
  if (isTauri()) {
    try {
      await deleteConnection(connId);
      await loadTauriState();
    } catch (err: any) {
      console.error('Failed to delete connection:', err);
      backendError.value = `Delete connection error: ${err?.message || String(err)}`;
    }
  }
}

async function handleConnectionCreated(conn: any) {
  if (isTauri()) {
    await loadTauriState(conn.id);
  }
}

function handleInspectValue(payload: { col: string; val: any }) {
  inspectorModal.value = {
    isOpen: true,
    col: payload.col,
    val: payload.val,
  };
}
</script>

<template>
  <div class="h-screen w-screen flex bg-slate-950 text-slate-100 overflow-hidden select-none">
    <!-- Sidebar -->
    <Sidebar
      ref="sidebarRef"
      :connections="localConnections"
      :active-connection="localActiveConnection"
      :schemas="localSchemas"
      :selected-schema="localSelectedSchema"
      :tables="localTables"
      :selected-table="localSelectedTable"
      :active-tab="currentTab"
      :selected-domain="selectedDomainId"
      @open-connection-modal="isConnectionModalOpen = true"
      @select-connection="handleSelectConnection"
      @delete-connection="handleDeleteConnection"
      @refresh-data="loadTauriState(localActiveConnection?.id, localSelectedSchema)"
      @select-tab="switchTab($event as any)"
      @select-table="handleSelectTable"
      @select-schema="handleSelectSchema"
      @select-domain="handleSelectDomain"
    />

    <!-- Main Workspace Area -->
    <main class="flex-1 flex flex-col h-full bg-slate-950 overflow-hidden relative">
      <!-- Backend Error or Flash Notification Banner -->
      <div
        v-if="backendError || flash?.notice || flash?.alert"
        :class="[
          'px-4 py-2 text-xs flex items-center justify-between border-b z-40 animate-in fade-in',
          backendError || flash?.alert
            ? 'bg-rose-950/90 border-rose-800 text-rose-200'
            : 'bg-emerald-950/80 border-emerald-800 text-emerald-300'
        ]"
      >
        <div class="flex items-center gap-2">
          <AlertCircle v-if="backendError || flash?.alert" class="w-4 h-4 text-rose-400 shrink-0" />
          <CheckCircle2 v-else class="w-4 h-4 text-emerald-400 shrink-0" />
          <span class="font-medium font-mono text-[11px]">{{ backendError || flash?.notice || flash?.alert }}</span>
        </div>
        <button
          v-if="backendError"
          @click="loadTauriState(localActiveConnection?.id, localSelectedSchema)"
          class="px-2 py-0.5 rounded bg-rose-900/60 hover:bg-rose-850 text-rose-200 border border-rose-700/60 text-[10px] font-bold uppercase tracking-wider transition"
        >
          Retry
        </button>
      </div>

      <!-- Top Tab Navigation Header -->
      <div class="h-11 px-4 bg-sumi-900 border-b border-sumi-750 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-1.5">
          <!-- Schema Domains Tab -->
          <button
            @click="switchTab('domains')"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-2 transition border',
              currentTab === 'domains'
                ? 'bg-sumi-950 text-indigo-700 dark:text-aizome-300 border-sumi-700 border-b-2 border-b-aizome-500 shadow-sm font-semibold'
                : 'text-sumi-400 hover:text-sumi-200 border-transparent hover:bg-sumi-850'
            ]"
          >
            <LayoutGrid class="w-3.5 h-3.5 text-indigo-600 dark:text-aizome-400" />
            <span>Domains</span>
            <span v-if="domainGroups.length > 0" class="px-1.5 py-0.2 rounded text-[10px] bg-sumi-800 text-sumi-200 font-mono">
              {{ domainGroups.length }}
            </span>
          </button>

          <!-- Table Structure Tab -->
          <button
            v-if="localSelectedTable"
            @click="switchTab('structure')"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-2 transition border',
              currentTab === 'structure'
                ? 'bg-sumi-950 text-indigo-700 dark:text-aizome-300 border-sumi-700 border-b-2 border-b-aizome-500 shadow-sm font-semibold'
                : 'text-sumi-400 hover:text-sumi-200 border-transparent hover:bg-sumi-850'
            ]"
          >
            <Layers class="w-3.5 h-3.5 text-indigo-600 dark:text-aizome-400" />
            <span>Structure: {{ localSelectedTable }}</span>
          </button>

          <!-- SQL Query Runner Tab -->
          <button
            @click="switchTab('query')"
            :class="[
              'px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-2 transition border',
              currentTab === 'query'
                ? 'bg-sumi-950 text-emerald-700 dark:text-matcha-300 border-sumi-700 border-b-2 border-b-matcha-500 shadow-sm font-semibold'
                : 'text-sumi-400 hover:text-sumi-200 border-transparent hover:bg-sumi-850'
            ]"
          >
            <Terminal class="w-3.5 h-3.5 text-emerald-600 dark:text-matcha-400" />
            <span>SQL Console</span>
          </button>
        </div>

        <!-- Right Action Items -->
        <div class="flex items-center gap-2.5">
          <!-- Connection Status Indicator -->
          <div class="flex items-center gap-2 text-xs text-sumi-400 font-mono px-2.5 py-1 rounded-xl bg-sumi-950/80 border border-sumi-750">
            <div class="w-2 h-2 rounded-full bg-matcha-500 shadow-[0_0_8px_rgba(16,185,129,0.8)]"></div>
            <span class="text-slate-200 font-medium">{{ localActiveConnection?.name || 'Demo Database' }}</span>
          </div>

          <!-- Quick Theme Switcher -->
          <button
            @click="toggleTheme"
            class="p-1.5 rounded-xl bg-sumi-850 hover:bg-sumi-800 text-sumi-300 dark:text-slate-300 hover:text-sumi-50 dark:hover:text-white border border-sumi-750 hover:border-sumi-600 transition shadow-sm"
            :title="nextThemeTitle"
          >
            <Moon v-if="theme === 'dark'" class="w-4 h-4 text-aizome-400" />
            <svg v-else-if="theme === 'matcha'" class="w-4 h-4 text-emerald-700 dark:text-matcha-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="9" />
              <path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor" stroke="none" />
            </svg>
            <Sun v-else class="w-4 h-4 text-yamabuki-400" />
          </button>
        </div>
      </div>

      <!-- Tab Content Area -->
      <div class="flex-1 overflow-hidden relative">
        <!-- 1. Domains Overview & Detail View -->
        <template v-if="currentTab === 'domains'">
          <DomainDetail
            v-if="activeDomain"
            :domain="activeDomain"
            :selected-schema="localSelectedSchema"
            :connection-id="localActiveConnection?.id"
            @back="selectedDomainId = null"
            @select-table="handleSelectTableFromDomain"
            @open-query="switchTab('query')"
          />
          <DomainOverview
            v-else
            :domains="domainGroups"
            :selected-schema="localSelectedSchema"
            :connection-id="localActiveConnection?.id"
            :connection-name="localActiveConnection?.name"
            :adapter="localActiveConnection?.adapter"
            @select-domain="handleSelectDomain"
            @select-table="handleSelectTableFromDomain"
            @open-query="switchTab('query')"
          />
        </template>

        <!-- 2. Table Structure View -->
        <template v-else-if="currentTab === 'structure' && localSelectedTable && localTableStructure">
          <TableStructure :structure="localTableStructure" />
        </template>

        <!-- 3. SQL Query Console View -->
        <template v-else-if="currentTab === 'query'">
          <SqlEditor
            :connection-id="localActiveConnection?.id"
            :default-table="localSelectedTable"
            :schema="localSelectedSchema"
            @inspect-value="handleInspectValue"
          />
        </template>

        <!-- Fallback -->
        <template v-else>
          <DomainOverview
            :domains="domainGroups"
            :selected-schema="localSelectedSchema"
            :connection-name="localActiveConnection?.name"
            :adapter="localActiveConnection?.adapter"
            @select-domain="handleSelectDomain"
            @select-table="handleSelectTableFromDomain"
            @open-query="switchTab('query')"
          />
        </template>
      </div>
    </main>

    <!-- Modals -->
    <ConnectionModal
      :is-open="isConnectionModalOpen"
      @connection-created="handleConnectionCreated"
      @close="isConnectionModalOpen = false"
    />

    <ValueInspectorModal
      :is-open="inspectorModal.isOpen"
      :column-name="inspectorModal.col"
      :raw-value="inspectorModal.val"
      @close="inspectorModal.isOpen = false"
    />
  </div>
</template>
