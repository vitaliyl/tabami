<script setup lang="ts">
import { ref, computed } from 'vue';
import {
  CalendarDays,
  CreditCard,
  Bot,
  ShieldCheck,
  Plug,
  ShoppingBag,
  History,
  Layers,
  Database,
  Table as TableIcon,
  Eye,
  ArrowLeft,
  Search,
  Terminal,
  Columns
} from 'lucide-vue-next';
import type { DomainGroup, TableItem } from '../utils/domainClassifier';

const props = defineProps<{
  domain: DomainGroup;
  selectedSchema: string;
  connectionId?: string;
}>();

const emit = defineEmits<{
  (e: 'back'): void;
  (e: 'select-table', table: TableItem, tab?: 'structure'): void;
  (e: 'open-query', tableName?: string): void;
}>();

const tableFilter = ref('');

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

function getIcon(name: string) {
  return iconMap[name] || Database;
}

const filteredTables = computed(() => {
  if (!tableFilter.value.trim()) return props.domain.tables;
  const q = tableFilter.value.toLowerCase().trim();
  return props.domain.tables.filter((t) => t.name.toLowerCase().includes(q));
});

function formatRowCount(count?: number) {
  if (count === undefined || count === null) return '0';
  if (count >= 1000000) return `${(count / 1000000).toFixed(1)}M`;
  if (count >= 1000) return `${(count / 1000).toFixed(1)}k`;
  return String(count);
}
</script>

<template>
  <div class="h-full overflow-y-auto bg-sumi-950 p-6 space-y-6">
    <!-- Breadcrumb & Back Navigation -->
    <div class="flex items-center justify-between pb-4 border-b border-sumi-750">
      <div class="flex items-center gap-2 text-xs">
        <button
          @click="emit('back')"
          class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-sumi-900 hover:bg-sumi-850 text-slate-300 hover:text-white border border-sumi-750 transition"
        >
          <ArrowLeft class="w-3.5 h-3.5" />
          <span>All Domains</span>
        </button>
        <span class="text-sumi-600">/</span>
        <span class="text-slate-300 font-semibold flex items-center gap-1.5">
          <span :class="['w-2 h-2 rounded-full', domain.color.text]"></span>
          {{ domain.name }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <button
          @click="emit('open-query')"
          class="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-sumi-900 hover:bg-sumi-850 text-sumi-300 dark:text-slate-300 hover:text-sumi-50 dark:hover:text-white border border-sumi-750 text-xs font-semibold transition"
        >
          <Terminal class="w-3.5 h-3.5 text-emerald-600 dark:text-matcha-400" />
          <span>SQL Console</span>
        </button>
      </div>
    </div>

    <!-- Domain Header Card -->
    <div :class="['rounded-2xl border p-6 flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-xl', domain.color.bg, domain.color.border]">
      <div class="flex items-start gap-4">
        <div :class="['w-14 h-14 rounded-2xl flex items-center justify-center border shadow-lg shrink-0', domain.color.badge, domain.color.text]">
          <component :is="getIcon(domain.iconName)" class="w-7 h-7" />
        </div>
        <div>
          <div class="flex items-center gap-2 mb-1">
            <h1 class="text-xl font-bold text-white tracking-tight">{{ domain.name }}</h1>
            <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-sumi-950/90 text-slate-300 border border-sumi-700 font-mono">
              {{ domain.id }}
            </span>
          </div>
          <p class="text-xs text-slate-300 max-w-xl leading-relaxed">
            {{ domain.description }}
          </p>
        </div>
      </div>

      <!-- Aggregate Badges -->
      <div class="flex items-center gap-3 self-start md:self-auto shrink-0">
        <div class="bg-sumi-950/90 border border-sumi-750 rounded-2xl px-4 py-2.5 text-center min-w-[90px] shadow-sm">
          <p class="text-[10px] uppercase font-semibold text-sumi-400 tracking-wider">Tables</p>
          <p class="text-base font-bold text-white font-mono">{{ domain.tableCount }}</p>
        </div>
        <div class="bg-sumi-950/90 border border-sumi-750 rounded-2xl px-4 py-2.5 text-center min-w-[90px] shadow-sm">
          <p class="text-[10px] uppercase font-semibold text-sumi-400 tracking-wider">Total Rows</p>
          <p class="text-base font-bold text-matcha-400 font-mono">{{ formatRowCount(domain.totalEstimatedRows) }}</p>
        </div>
      </div>
    </div>

    <!-- Tables Catalog View -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2">
      <div class="relative max-w-md w-full">
        <Search class="w-4 h-4 text-sumi-400 absolute left-3 top-1/2 -translate-y-1/2" />
        <input
          v-model="tableFilter"
          type="text"
          :placeholder="`Filter ${domain.tables.length} tables in ${domain.name}...`"
          class="w-full bg-sumi-900 border border-sumi-750 rounded-xl pl-9 pr-4 py-2 text-xs text-white placeholder-sumi-500 focus:outline-none focus:border-ruby-500 focus:ring-1 focus:ring-ruby-500/30 transition shadow-inner"
        />
      </div>

      <span class="text-xs font-mono text-sumi-400">
        Showing {{ filteredTables.length }} of {{ domain.tables.length }} tables
      </span>
    </div>

    <!-- Tables Catalog Grid -->
    <div class="grid grid-cols-1 gap-2.5 pb-10">
      <div
        v-for="table in filteredTables"
        :key="table.name"
        class="bg-sumi-900/90 hover:bg-sumi-850 border border-sumi-750 hover:border-sumi-600 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition duration-150 group shadow-sm"
      >
        <!-- Table Name & Type -->
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-xl bg-sumi-950 border border-sumi-750 flex items-center justify-center text-sumi-400 group-hover:text-ruby-400 group-hover:border-sumi-600 transition shrink-0">
            <TableIcon v-if="table.type === 'table'" class="w-4 h-4" />
            <Eye v-else class="w-4 h-4 text-aizome-400" />
          </div>
          <div>
            <div class="flex items-center gap-2">
              <button
                @click="emit('select-table', table, 'structure')"
                class="text-sm font-bold font-mono text-white group-hover:text-ruby-400 transition hover:underline text-left"
              >
                {{ table.name }}
              </button>
              <span
                :class="[
                  'px-1.5 py-0.5 rounded text-[10px] uppercase font-bold tracking-wider font-mono border',
                  table.type === 'table'
                    ? 'bg-sumi-950 text-sumi-400 border-sumi-750'
                    : 'bg-aizome-950/60 text-aizome-300 border-aizome-800/60'
                ]"
              >
                {{ table.type }}
              </span>
            </div>
            <p class="text-[11px] text-sumi-400 font-mono mt-0.5">
              schema: {{ table.schema }}
            </p>
          </div>
        </div>

        <!-- Row Count & Action Buttons -->
        <div class="flex items-center gap-3 self-end sm:self-center">
          <span
            v-if="table.estimated_rows !== undefined && table.estimated_rows !== null"
            class="px-2.5 py-1 rounded-xl bg-sumi-950 border border-sumi-750 text-xs font-mono text-slate-300"
            title="Estimated row count"
          >
            ~{{ formatRowCount(table.estimated_rows) }} rows
          </span>

          <div class="flex items-center gap-1.5">
            <button
              @click="emit('open-query', table.name)"
              class="px-3 py-1.5 rounded-xl bg-sumi-850 hover:bg-sumi-800 text-slate-300 hover:text-white border border-sumi-750 text-xs font-semibold flex items-center gap-1.5 transition shadow-sm"
              title="Query table in SQL Console"
            >
              <Terminal class="w-3.5 h-3.5 text-emerald-400" />
              <span>Query</span>
            </button>

            <button
              @click="emit('select-table', table, 'structure')"
              class="px-3 py-1.5 rounded-xl bg-sumi-850 hover:bg-aizome-600 text-slate-300 hover:text-white border border-sumi-750 hover:border-aizome-500 text-xs font-semibold flex items-center gap-1.5 transition shadow-sm"
              title="Inspect table structure & schema"
            >
              <Columns class="w-3.5 h-3.5" />
              <span>Structure</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
