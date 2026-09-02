<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { router } from '@inertiajs/vue3';
import {
  isTauri,
  testConnection as apiTestConnection,
  saveConnection as apiSaveConnection,
  discoverDatabases as apiDiscoverDatabases
} from '../utils/api';
import {
  X,
  Database,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Server,
  FileCode,
  ShieldCheck,
  Compass,
  Search,
  ArrowLeft,
  Check,
  RefreshCw,
  Layers,
  ChevronRight
} from 'lucide-vue-next';

const props = defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'connection-created', conn: any): void;
}>();

const currentView = ref<'form' | 'picker'>('form');
const searchQuery = ref('');
const tempSelectedDb = ref('');

const form = ref({
  name: '',
  adapter: 'postgres',
  host: 'localhost',
  port: 5432,
  database: '',
  username: 'postgres',
  password: '',
  file_path: '',
  ssl: false,
});

const testing = ref(false);
const testResult = ref<{ success: boolean; message?: string; error?: string; server_version?: string } | null>(null);
const submitting = ref(false);

const discovering = ref(false);
const discoveredDatabases = ref<string[]>([]);
const isPgBouncer = ref(false);
const discoveryMessage = ref<string | null>(null);
const discoveryError = ref<string | null>(null);

const filteredDatabases = computed(() => {
  if (!searchQuery.value.trim()) return discoveredDatabases.value;
  const q = searchQuery.value.toLowerCase().trim();
  return discoveredDatabases.value.filter(db => db.toLowerCase().includes(q));
});

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      currentView.value = 'form';
      searchQuery.value = '';
      testResult.value = null;
      discoveryError.value = null;
    }
  }
);

watch(
  () => form.value.adapter,
  (newVal) => {
    testResult.value = null;
    discoveredDatabases.value = [];
    discoveryError.value = null;
    discoveryMessage.value = null;
    isPgBouncer.value = false;
    currentView.value = 'form';

    if (newVal === 'postgres') {
      form.value.port = 5432;
      form.value.username = 'postgres';
      if (!form.value.name || form.value.name.includes('SQLite') || form.value.name.includes('MySQL')) {
        form.value.name = 'PostgreSQL Local';
      }
    } else if (newVal === 'mysql') {
      form.value.port = 3306;
      form.value.username = 'root';
      if (!form.value.name || form.value.name.includes('Postgre') || form.value.name.includes('SQLite')) {
        form.value.name = 'MySQL Local';
      }
    } else if (newVal === 'sqlite') {
      form.value.file_path = 'db/demo.sqlite3';
      if (!form.value.name || form.value.name.includes('Postgre') || form.value.name.includes('MySQL')) {
        form.value.name = 'Local SQLite Database';
      }
    }
  },
  { immediate: true }
);

async function testConnection() {
  testing.value = true;
  testResult.value = null;
  try {
    const payload = {
      ...form.value,
      user: form.value.username || (form.value as any).user || 'postgres',
      database: form.value.database || (form.value.adapter === 'postgres' ? 'postgres' : ''),
    };
    if (isTauri()) {
      const data = await apiTestConnection(payload);
      testResult.value = data;
    } else {
      const res = await fetch('/connections/test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      testResult.value = data;
    }
  } catch (err: any) {
    testResult.value = {
      success: false,
      message: err.message || 'Error occurred while testing connection.',
    };
  } finally {
    testing.value = false;
  }
}

async function discoverDatabases(autoOpenPicker = false) {
  discovering.value = true;
  discoveryError.value = null;
  discoveryMessage.value = null;
  discoveredDatabases.value = [];
  isPgBouncer.value = false;

  try {
    const payload = {
      ...form.value,
      port: form.value.port ? Number(form.value.port) : undefined,
      user: form.value.username || (form.value as any).user || 'postgres',
    };
    const data = await apiDiscoverDatabases(payload);
    if (data.success && data.databases && data.databases.length > 0) {
      discoveredDatabases.value = data.databases;
      isPgBouncer.value = data.is_pgbouncer || false;
      discoveryMessage.value = data.message || `Discovered ${data.databases.length} database(s)`;
      if (!form.value.database || !data.databases.includes(form.value.database)) {
        form.value.database = data.databases[0];
      }
      tempSelectedDb.value = form.value.database;
      if (autoOpenPicker) {
        searchQuery.value = '';
        currentView.value = 'picker';
      }
    } else {
      discoveryError.value = data.message || 'No accessible databases or pools found on this host/port.';
    }
  } catch (err: any) {
    discoveryError.value = err.message || 'Error occurred while discovering databases.';
  } finally {
    discovering.value = false;
  }
}

async function openPicker() {
  if (discoveredDatabases.value.length === 0) {
    await discoverDatabases(true);
  } else {
    tempSelectedDb.value = form.value.database || discoveredDatabases.value[0] || '';
    searchQuery.value = '';
    currentView.value = 'picker';
  }
}

function selectDatabase(db: string) {
  tempSelectedDb.value = db;
}

function confirmSelection(andConnect = false) {
  if (tempSelectedDb.value) {
    if (form.value.adapter === 'sqlite') {
      form.value.file_path = tempSelectedDb.value;
    } else {
      form.value.database = tempSelectedDb.value;
    }
  }
  currentView.value = 'form';
  if (andConnect) {
    submit();
  }
}

async function submit() {
  submitting.value = true;
  const payload = {
    ...form.value,
    user: form.value.username || (form.value as any).user || 'postgres',
    database: form.value.database || (form.value.adapter === 'postgres' ? 'postgres' : ''),
  };
  if (isTauri()) {
    try {
      const saved = await apiSaveConnection(payload);
      submitting.value = false;
      emit('connection-created', saved);
      emit('close');
    } catch (err: any) {
      submitting.value = false;
      testResult.value = {
        success: false,
        message: err.message || 'Failed to save connection',
      };
    }
  } else {
    router.post('/connections', { connection: payload }, {
      onSuccess: () => {
        submitting.value = false;
        emit('close');
      },
      onError: () => {
        submitting.value = false;
      }
    });
  }
}
</script>

<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in duration-200">
    <div class="bg-slate-900 border border-slate-700 rounded-xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh]">
      
      <!-- VIEW 1: MAIN FORM -->
      <template v-if="currentView === 'form'">
        <div class="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/50">
          <div class="flex items-center gap-3">
            <div class="p-2 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <Database class="w-5 h-5" />
            </div>
            <div>
              <h3 class="text-base font-semibold text-white">Add Database Connection</h3>
              <p class="text-xs text-slate-400">Connect to PostgreSQL, SQLite, or MySQL</p>
            </div>
          </div>
          <button
            @click="emit('close')"
            class="text-slate-400 hover:text-white p-1 rounded-md hover:bg-slate-800 transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <form @submit.prevent="submit" class="p-6 overflow-y-auto space-y-4 flex-1">
          <div>
            <label class="block text-xs font-semibold text-sumi-400 uppercase tracking-wider mb-2">Database Engine</label>
            <div class="grid grid-cols-3 gap-2">
              <button
                type="button"
                @click="form.adapter = 'postgres'"
                :class="[
                  'flex flex-col items-center justify-center p-3 rounded-xl border text-xs font-semibold transition',
                  form.adapter === 'postgres'
                    ? 'bg-sumi-800 border-aizome-500 text-aizome-300 ring-1 ring-aizome-500/50 shadow-sm'
                    : 'bg-sumi-850 border-sumi-750 text-slate-300 hover:bg-sumi-800'
                ]"
              >
                <Server class="w-5 h-5 mb-1.5 text-aizome-400" />
                PostgreSQL
              </button>
              <button
                type="button"
                @click="form.adapter = 'sqlite'"
                :class="[
                  'flex flex-col items-center justify-center p-3 rounded-xl border text-xs font-semibold transition',
                  form.adapter === 'sqlite'
                    ? 'bg-sumi-800 border-aizome-500 text-aizome-300 ring-1 ring-aizome-500/50 shadow-sm'
                    : 'bg-sumi-850 border-sumi-750 text-slate-300 hover:bg-sumi-800'
                ]"
              >
                <FileCode class="w-5 h-5 mb-1.5 text-matcha-400" />
                SQLite
              </button>
              <button
                type="button"
                @click="form.adapter = 'mysql'"
                :class="[
                  'flex flex-col items-center justify-center p-3 rounded-xl border text-xs font-semibold transition',
                  form.adapter === 'mysql'
                    ? 'bg-sumi-800 border-aizome-500 text-aizome-300 ring-1 ring-aizome-500/50 shadow-sm'
                    : 'bg-sumi-850 border-sumi-750 text-slate-300 hover:bg-sumi-800'
                ]"
              >
                <Database class="w-5 h-5 mb-1.5 text-yamabuki-400" />
                MySQL
              </button>
            </div>
          </div>

          <div>
            <label class="block text-xs font-medium text-slate-300 mb-1">Display Name</label>
            <input
              v-model="form.name"
              type="text"
              required
              placeholder="e.g. Production PostgreSQL"
              class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
            />
          </div>

          <!-- SQLite Fields -->
          <template v-if="form.adapter === 'sqlite'">
            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-medium text-slate-300">SQLite File Path</label>
                <button
                  type="button"
                  @click="openPicker"
                  :disabled="discovering"
                  class="text-[11px] font-medium text-emerald-400 hover:text-emerald-300 flex items-center gap-1 transition disabled:opacity-50 py-0.5 px-1.5 rounded hover:bg-emerald-500/10"
                >
                  <Loader2 v-if="discovering" class="w-3 h-3 animate-spin" />
                  <Compass v-else class="w-3 h-3" />
                  <span>{{ discovering ? 'Scanning...' : 'Find Local DBs' }}</span>
                </button>
              </div>
              <input
                v-model="form.file_path"
                type="text"
                required
                placeholder="e.g. db/demo.sqlite3"
                class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm font-mono text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
              />
            </div>
          </template>

          <!-- Network DB Fields (Postgres / MySQL) -->
          <template v-else>
            <div class="grid grid-cols-3 gap-3">
              <div class="col-span-2">
                <label class="block text-xs font-medium text-slate-300 mb-1">Host / Server</label>
                <input
                  v-model="form.host"
                  type="text"
                  required
                  placeholder="localhost or 127.0.0.1"
                  class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-300 mb-1">Port</label>
                <input
                  v-model="form.port"
                  type="number"
                  required
                  class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm font-mono text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
                />
              </div>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-medium text-slate-300">Database Name</label>
                <button
                  type="button"
                  @click="openPicker"
                  :disabled="discovering"
                  class="text-[11px] font-medium text-emerald-400 hover:text-emerald-300 flex items-center gap-1 transition disabled:opacity-50 py-0.5 px-1.5 rounded hover:bg-emerald-500/10"
                >
                  <Loader2 v-if="discovering" class="w-3 h-3 animate-spin" />
                  <Compass v-else class="w-3 h-3" />
                  <span>
                    {{ discovering ? 'Discovering...' : (discoveredDatabases.length > 0 ? `Browse Databases (${discoveredDatabases.length})` : 'Discover Databases') }}
                  </span>
                </button>
              </div>
              
              <div class="relative flex items-center">
                <input
                  v-model="form.database"
                  type="text"
                  required
                  placeholder="e.g. my_database"
                  :class="[
                    'w-full bg-slate-950 border border-slate-700 rounded-lg pl-3 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition',
                    discoveredDatabases.length > 0 ? 'pr-24' : 'pr-3'
                  ]"
                />
                <button
                  v-if="discoveredDatabases.length > 0"
                  type="button"
                  @click="openPicker"
                  class="absolute right-1.5 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-[11px] font-medium text-emerald-400 border border-slate-700 flex items-center gap-1 transition shadow-sm"
                >
                  <Layers class="w-3 h-3" />
                  <span>Pick ({{ discoveredDatabases.length }})</span>
                </button>
              </div>

              <div v-if="discoveryError" class="mt-1.5 p-2 rounded bg-rose-950/30 border border-rose-900/50 text-[11px] text-rose-300 flex items-start gap-1.5">
                <AlertCircle class="w-3.5 h-3.5 shrink-0 mt-0.5 text-rose-400" />
                <span>{{ discoveryError }}</span>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-medium text-slate-300 mb-1">Username</label>
                <input
                  v-model="form.username"
                  type="text"
                  placeholder="postgres / root"
                  class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-300 mb-1">Password</label>
                <input
                  v-model="form.password"
                  type="password"
                  placeholder="••••••••"
                  class="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition"
                />
              </div>
            </div>

            <div class="flex items-center gap-2 pt-1">
              <input
                id="ssl_check"
                v-model="form.ssl"
                type="checkbox"
                class="rounded border-slate-700 bg-slate-950 text-emerald-500 focus:ring-emerald-500 focus:ring-offset-slate-900"
              />
              <label for="ssl_check" class="text-xs text-slate-300 flex items-center gap-1 cursor-pointer">
                <ShieldCheck class="w-3.5 h-3.5 text-slate-400" />
                Require SSL Encryption (sslmode=require)
              </label>
            </div>
          </template>

          <div
            v-if="testResult"
            :class="[
              'p-3 rounded-lg border text-xs flex items-start gap-2.5',
              testResult.success
                ? 'bg-emerald-950/40 border-emerald-800 text-emerald-300'
                : 'bg-rose-950/40 border-rose-800 text-rose-300'
            ]"
          >
            <CheckCircle2 v-if="testResult.success" class="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
            <AlertCircle v-else class="w-4 h-4 text-rose-400 shrink-0 mt-0.5" />
            <div>
              <p class="font-semibold">{{ testResult.message || testResult.error }}</p>
              <p v-if="testResult.server_version" class="text-[11px] opacity-80 mt-0.5 font-mono">
                Server: {{ testResult.server_version }}
              </p>
            </div>
          </div>
        </form>

        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900/80 flex items-center justify-between">
          <button
            type="button"
            @click="testConnection"
            :disabled="testing"
            class="px-3.5 py-2 rounded-lg border border-slate-700 bg-slate-800 text-xs font-medium text-slate-200 hover:bg-slate-700 hover:text-white transition flex items-center gap-1.5 disabled:opacity-50"
          >
            <Loader2 v-if="testing" class="w-3.5 h-3.5 animate-spin" />
            <span>{{ testing ? 'Testing...' : 'Test Connection' }}</span>
          </button>

          <div class="flex items-center gap-2">
            <button
              type="button"
              @click="emit('close')"
              class="px-4 py-2 rounded-lg text-xs font-medium text-slate-400 hover:text-white transition"
            >
              Cancel
            </button>
            <button
              type="button"
              @click="submit"
              :disabled="submitting"
              class="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-700 hover:from-emerald-500 hover:to-teal-600 text-xs font-semibold text-white shadow-lg shadow-emerald-950/60 border border-emerald-400/30 transition flex items-center gap-1.5 disabled:opacity-50"
            >
              <Loader2 v-if="submitting" class="w-3.5 h-3.5 animate-spin" />
              <span>{{ submitting ? 'Saving...' : 'Save & Connect' }}</span>
            </button>
          </div>
        </div>
      </template>

      <!-- VIEW 2: DATABASE PICKER -->
      <template v-else-if="currentView === 'picker'">
        <div class="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/50">
          <div class="flex items-center gap-3">
            <button
              type="button"
              @click="currentView = 'form'"
              class="p-1.5 rounded-lg border border-slate-700 text-slate-300 hover:text-white hover:bg-slate-800 transition flex items-center gap-1 text-xs"
            >
              <ArrowLeft class="w-4 h-4" />
            </button>
            <div>
              <div class="flex items-center gap-2">
                <h3 class="text-base font-semibold text-white">Database Picker</h3>
                <span
                  v-if="isPgBouncer"
                  class="px-2 py-0.5 rounded text-[10px] bg-amber-500/10 text-amber-400 border border-amber-500/20 font-semibold"
                >
                  PgBouncer Pools
                </span>
              </div>
              <p class="text-xs text-slate-400 font-mono">
                <span v-if="form.adapter !== 'sqlite'">{{ form.host }}:{{ form.port }} · </span>
                <span>{{ discoveredDatabases.length }} database(s) found</span>
              </p>
            </div>
          </div>
          <button
            @click="emit('close')"
            class="text-slate-400 hover:text-white p-1 rounded-md hover:bg-slate-800 transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-6 overflow-y-auto space-y-3.5 flex-1 flex flex-col min-h-0">
          <div class="flex items-center gap-2">
            <div class="relative flex-1">
              <Search class="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                v-model="searchQuery"
                type="text"
                autofocus
                :placeholder="`Filter ${discoveredDatabases.length} databases...`"
                class="w-full bg-slate-950 border border-slate-700 rounded-lg pl-9 pr-8 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition font-mono"
              />
              <button
                v-if="searchQuery"
                type="button"
                @click="searchQuery = ''"
                class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white p-0.5"
              >
                <X class="w-3.5 h-3.5" />
              </button>
            </div>

            <button
              type="button"
              @click="discoverDatabases(false)"
              :disabled="discovering"
              class="px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-200 hover:bg-slate-700 hover:text-white transition flex items-center gap-1.5 text-xs font-medium shrink-0 disabled:opacity-50"
            >
              <RefreshCw :class="['w-3.5 h-3.5', discovering && 'animate-spin']" />
              <span class="hidden sm:inline">Refresh</span>
            </button>
          </div>

          <div class="flex items-center justify-between text-xs text-slate-400 px-0.5">
            <span>
              Showing <strong class="text-white">{{ filteredDatabases.length }}</strong> of {{ discoveredDatabases.length }}
            </span>
            <span v-if="tempSelectedDb" class="text-emerald-400 font-mono text-[11px] truncate max-w-[200px]">
              Selected: <span class="font-semibold text-emerald-300">{{ tempSelectedDb }}</span>
            </span>
          </div>

          <div class="border border-slate-800 rounded-lg bg-slate-950/60 divide-y divide-slate-800/80 overflow-y-auto max-h-[320px] flex-1">
            <template v-if="filteredDatabases.length > 0">
              <button
                v-for="dbName in filteredDatabases"
                :key="dbName"
                type="button"
                @click="selectDatabase(dbName)"
                @dblclick="confirmSelection(false)"
                :class="[
                  'w-full px-4 py-2.5 flex items-center justify-between text-left transition group',
                  tempSelectedDb === dbName
                    ? 'bg-emerald-500/10 text-emerald-300'
                    : 'hover:bg-slate-800/60 text-slate-300 hover:text-white'
                ]"
              >
                <div class="flex items-center gap-2.5 min-w-0">
                  <div
                    :class="[
                      'p-1.5 rounded-md transition',
                      tempSelectedDb === dbName
                        ? 'bg-emerald-500/20 text-emerald-400 ring-1 ring-emerald-500/40'
                        : 'bg-slate-800 text-slate-400 group-hover:text-slate-200'
                    ]"
                  >
                    <Database class="w-4 h-4" />
                  </div>
                  <span class="font-mono text-xs truncate font-medium">{{ dbName }}</span>
                </div>

                <div class="flex items-center gap-2 shrink-0">
                  <span
                    v-if="tempSelectedDb === dbName"
                    class="px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center gap-1 shadow-sm"
                  >
                    <Check class="w-3 h-3" />
                    Selected
                  </span>
                  <ChevronRight v-else class="w-4 h-4 text-slate-600 group-hover:text-slate-400 transition" />
                </div>
              </button>
            </template>

            <div v-else class="py-12 px-4 text-center">
              <Database class="w-8 h-8 text-slate-600 mx-auto mb-2 opacity-50" />
              <p class="text-xs text-slate-400 font-medium">No databases matching "{{ searchQuery }}"</p>
            </div>
          </div>
        </div>

        <div class="px-6 py-4 border-t border-slate-800 bg-slate-900/80 flex items-center justify-between">
          <button
            type="button"
            @click="currentView = 'form'"
            class="px-4 py-2 rounded-lg text-xs font-medium text-slate-400 hover:text-white transition"
          >
            Back to Form
          </button>

          <div class="flex items-center gap-2">
            <button
              type="button"
              @click="confirmSelection(false)"
              :disabled="!tempSelectedDb"
              class="px-4 py-2 rounded-lg border border-slate-700 bg-slate-800 text-xs font-medium text-slate-200 hover:bg-slate-700 hover:text-white transition disabled:opacity-50"
            >
              Select & Return
            </button>
            <button
              type="button"
              @click="confirmSelection(true)"
              :disabled="!tempSelectedDb || submitting"
              class="px-4 py-2 rounded-lg bg-emerald-600 text-xs font-semibold text-white hover:bg-emerald-500 shadow-lg shadow-emerald-900/30 transition flex items-center gap-1.5 disabled:opacity-50"
            >
              <Loader2 v-if="submitting" class="w-3.5 h-3.5 animate-spin" />
              <span>Select & Connect</span>
            </button>
          </div>
        </div>
      </template>

    </div>
  </div>
</template>
