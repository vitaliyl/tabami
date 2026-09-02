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
  ArrowRight,
  Search,
  Terminal
} from 'lucide-vue-next';
import type { DomainGroup, TableItem } from '../utils/domainClassifier';

const props = defineProps<{
  domains: DomainGroup[];
  selectedSchema: string;
  connectionId?: string;
  connectionName?: string;
  adapter?: string;
}>();

const emit = defineEmits<{
  (e: 'select-domain', domainId: string): void;
  (e: 'select-table', table: TableItem): void;
  (e: 'open-query'): void;
}>();

const searchQuery = ref('');

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

const totalTables = computed(() =>
  props.domains.reduce((acc, d) => acc + d.tableCount, 0)
);

const totalEstimatedRows = computed(() =>
  props.domains.reduce((acc, d) => acc + d.totalEstimatedRows, 0)
);

const filteredDomains = computed(() => {
  if (!searchQuery.value.trim()) return props.domains;
  const q = searchQuery.value.toLowerCase().trim();
  return props.domains
    .map((domain) => {
      const matchesDomain =
        domain.name.toLowerCase().includes(q) ||
        domain.description.toLowerCase().includes(q);
      const matchingTables = domain.tables.filter((t) =>
        t.name.toLowerCase().includes(q)
      );
      if (matchesDomain || matchingTables.length > 0) {
        return {
          ...domain,
          tables: matchingTables.length > 0 ? matchingTables : domain.tables,
        };
      }
      return null;
    })
    .filter(Boolean) as DomainGroup[];
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
    <!-- Header Banner -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-5 border-b border-sumi-750">
      <div>
        <div class="flex items-center gap-2 mb-1">
          <span class="px-2 py-0.5 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-ruby-500/10 text-ruby-400 border border-ruby-500/20 flex items-center gap-1">
            <Layers class="w-3 h-3" />
            Schema Domains
          </span>
          <span class="text-xs text-sumi-400 font-mono">schema: {{ selectedSchema }}</span>
        </div>
        <h1 class="text-xl font-extrabold text-white tracking-tight">Discovered Schema Domains</h1>
        <p class="text-xs text-sumi-400 mt-0.5">
          Automatic bounded context clustering for {{ connectionName || 'database' }} ({{ adapter || 'SQL' }}).
        </p>
      </div>

      <!-- Quick Stats -->
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-3 bg-sumi-900 border border-sumi-750 rounded-2xl px-3.5 py-2 shadow-sm">
          <div class="text-center pr-3 border-r border-sumi-750">
            <p class="text-[10px] uppercase font-semibold text-sumi-400 tracking-wider">Domains</p>
            <p class="text-sm font-bold text-white font-mono">{{ domains.length }}</p>
          </div>
          <div class="text-center pr-3 border-r border-sumi-750">
            <p class="text-[10px] uppercase font-semibold text-sumi-400 tracking-wider">Tables</p>
            <p class="text-sm font-bold text-matcha-400 font-mono">{{ totalTables }}</p>
          </div>
          <div class="text-center">
            <p class="text-[10px] uppercase font-semibold text-sumi-400 tracking-wider">Est. Rows</p>
            <p class="text-sm font-bold text-aizome-400 font-mono">{{ formatRowCount(totalEstimatedRows) }}</p>
          </div>
        </div>

        <button
          @click="emit('open-query')"
          class="hidden sm:flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-sumi-900 hover:bg-sumi-850 text-slate-300 hover:text-white border border-sumi-750 text-xs font-semibold transition"
          title="Open SQL Console"
        >
          <Terminal class="w-4 h-4 text-ruby-400" />
          <span>SQL Console</span>
        </button>
      </div>
    </div>

    <!-- Search / Filter Bar -->
    <div class="relative max-w-md">
      <Search class="w-4 h-4 text-sumi-400 absolute left-3 top-1/2 -translate-y-1/2" />
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Filter domains or table names..."
        class="w-full bg-sumi-900 border border-sumi-750 rounded-xl pl-9 pr-4 py-2 text-xs text-white placeholder-sumi-500 focus:outline-none focus:border-ruby-500 focus:ring-1 focus:ring-ruby-500/30 transition shadow-inner"
      />
    </div>

    <!-- No domains match -->
    <div v-if="filteredDomains.length === 0" class="text-center py-16 text-sumi-400 text-xs">
      No domains or tables match "{{ searchQuery }}"
    </div>

    <!-- Domains Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5 pb-8">
      <div
        v-for="domain in filteredDomains"
        :key="domain.id"
        class="group relative bg-sumi-900/90 hover:bg-sumi-850 border border-sumi-750 hover:border-sumi-600 rounded-2xl p-5 flex flex-col justify-between transition duration-200 hover:shadow-2xl hover:shadow-black/60 cursor-pointer"
        @click="emit('select-domain', domain.id)"
      >
        <!-- Top Domain Card Info -->
        <div>
          <div class="flex items-start justify-between gap-3 mb-3">
            <div class="flex items-center gap-3">
              <div :class="['w-10 h-10 rounded-xl flex items-center justify-center border shadow-md shrink-0', domain.color.bg, domain.color.text, domain.color.border]">
                <component :is="getIcon(domain.iconName)" class="w-5 h-5" />
              </div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="text-sm font-bold text-white group-hover:text-ruby-400 transition">
                    {{ domain.name }}
                  </h3>
                </div>
                <span class="text-[10px] text-sumi-400 font-mono">
                  {{ domain.tableCount }} {{ domain.tableCount === 1 ? 'table' : 'tables' }}
                  <template v-if="domain.totalEstimatedRows > 0">
                    • ~{{ formatRowCount(domain.totalEstimatedRows) }} rows
                  </template>
                </span>
              </div>
            </div>

            <span class="p-1.5 rounded-lg bg-sumi-950 border border-sumi-750 text-sumi-400 group-hover:text-white group-hover:border-sumi-600 transition">
              <ArrowRight class="w-3.5 h-3.5" />
            </span>
          </div>

          <p class="text-xs text-sumi-300 line-clamp-2 mb-4 leading-relaxed">
            {{ domain.description }}
          </p>

          <!-- Table preview chips -->
          <div class="space-y-1.5 pt-2 border-t border-sumi-800">
            <div class="text-[10px] font-semibold uppercase tracking-wider text-sumi-400 mb-1.5 flex items-center justify-between">
              <span>Tables in domain</span>
              <span class="font-mono">{{ domain.tables.length }} total</span>
            </div>

            <div class="grid grid-cols-1 gap-1">
              <button
                v-for="table in domain.tables.slice(0, 4)"
                :key="table.name"
                @click.stop="emit('select-table', table)"
                class="w-full flex items-center justify-between px-2 py-1 rounded-md bg-slate-950/70 hover:bg-slate-800 border border-slate-850 hover:border-slate-700 text-left transition group/tbl"
              >
                <div class="flex items-center gap-1.5 truncate">
                  <TableIcon v-if="table.type === 'table'" class="w-3 h-3 text-slate-400 group-hover/tbl:text-emerald-400 shrink-0" />
                  <Eye v-else class="w-3 h-3 text-indigo-400 shrink-0" />
                  <span class="text-xs font-mono text-slate-300 group-hover/tbl:text-white truncate">
                    {{ table.name }}
                  </span>
                </div>
                <span v-if="table.estimated_rows !== undefined && table.estimated_rows !== null" class="text-[10px] font-mono text-slate-400 shrink-0">
                  {{ formatRowCount(table.estimated_rows) }}
                </span>
              </button>
            </div>

            <div v-if="domain.tables.length > 4" class="text-[10px] text-slate-400 font-mono pt-1 text-right">
              + {{ domain.tables.length - 4 }} more tables...
            </div>
          </div>
        </div>

        <div class="mt-4 pt-3 border-t border-slate-800/60 flex items-center justify-between text-xs text-slate-400 group-hover:text-emerald-400 font-medium transition">
          <span>Explore domain catalog</span>
          <ArrowRight class="w-3.5 h-3.5 group-hover:translate-x-0.5 transition" />
        </div>
      </div>
    </div>
  </div>
</template>
