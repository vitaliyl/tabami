<script setup lang="ts">
import { Key, Link, Bookmark, Hash, Layers } from 'lucide-vue-next';

interface Column {
  name: string;
  type: string;
  db_type: string;
  allow_null: boolean;
  default?: string;
  primary_key: boolean;
  max_length?: number;
  numeric_precision?: number;
  numeric_scale?: number;
}

interface ForeignKey {
  name: string;
  columns: string[];
  table: string;
  key: string[];
  on_delete?: string;
  on_update?: string;
}

interface Index {
  name: string;
  columns: string[];
  unique: boolean;
}

interface TableStructureData {
  table_name: string;
  schema: string;
  columns: Column[];
  primary_keys: string[];
  foreign_keys: ForeignKey[];
  indexes: Index[];
  total_rows: number;
}

defineProps<{
  structure: TableStructureData;
}>();
</script>

<template>
  <div class="flex-1 overflow-y-auto p-6 bg-sumi-950 space-y-6 select-text">
    <!-- Header Summary -->
    <div class="flex items-center justify-between bg-sumi-900 p-4 rounded-2xl border border-sumi-750 shadow-sm">
      <div>
        <h2 class="text-base font-mono font-bold text-white flex items-center gap-2">
          <Layers class="w-4 h-4 text-aizome-400" />
          {{ structure.schema }}.{{ structure.table_name }}
        </h2>
        <p class="text-xs text-sumi-400 mt-0.5">
          {{ structure.columns.length }} columns • {{ structure.total_rows }} total rows
        </p>
      </div>

      <div v-if="structure.primary_keys.length > 0" class="flex items-center gap-1.5 bg-yamabuki-950/60 border border-yamabuki-800/80 px-3 py-1.5 rounded-xl text-xs text-yamabuki-300">
        <Key class="w-3.5 h-3.5 text-yamabuki-400" />
        <span>Primary Key: <strong class="font-mono text-white">{{ structure.primary_keys.join(', ') }}</strong></span>
      </div>
    </div>

    <!-- Section 1: Columns -->
    <div class="bg-sumi-900 rounded-2xl border border-sumi-750 overflow-hidden shadow-sm">
      <div class="px-4 py-3 border-b border-sumi-750 flex items-center gap-2 bg-sumi-950/40">
        <Hash class="w-4 h-4 text-aizome-400" />
        <h3 class="text-xs font-semibold text-white uppercase tracking-wider">Columns Schema</h3>
      </div>

      <div class="overflow-x-auto font-mono text-xs">
        <table class="w-full text-left">
          <thead class="bg-sumi-950 border-b border-sumi-750 text-sumi-400 text-[11px] uppercase tracking-wider">
            <tr>
              <th class="px-4 py-2.5">Name</th>
              <th class="px-4 py-2.5">Type</th>
              <th class="px-4 py-2.5">DB Type</th>
              <th class="px-4 py-2.5">Nullable</th>
              <th class="px-4 py-2.5">Default</th>
              <th class="px-4 py-2.5">Key</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-sumi-800 text-slate-200">
            <tr v-for="col in structure.columns" :key="col.name" class="hover:bg-sumi-850 transition">
              <td class="px-4 py-2.5 font-bold text-white flex items-center gap-1.5">
                <Key v-if="col.primary_key" class="w-3.5 h-3.5 text-yamabuki-400 shrink-0" />
                {{ col.name }}
              </td>
              <td class="px-4 py-2.5 text-matcha-400 font-medium">{{ col.type }}</td>
              <td class="px-4 py-2.5 text-sumi-400">{{ col.db_type }}</td>
              <td class="px-4 py-2.5">
                <span :class="col.allow_null ? 'text-yamabuki-400' : 'text-sumi-500'">
                  {{ col.allow_null ? 'YES' : 'NO' }}
                </span>
              </td>
              <td class="px-4 py-2.5 text-sumi-400 italic">
                {{ col.default !== undefined && col.default !== null ? col.default : '—' }}
              </td>
              <td class="px-4 py-2.5">
                <span v-if="col.primary_key" class="px-2 py-0.5 rounded text-[10px] font-bold bg-yamabuki-500/10 text-yamabuki-400 border border-yamabuki-500/30">
                  PRIMARY
                </span>
                <span v-else class="text-sumi-600">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Section 2: Foreign Keys & Indexes Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <!-- Foreign Keys -->
      <div class="bg-slate-900/80 rounded-xl border border-slate-800 overflow-hidden">
        <div class="px-4 py-3 border-b border-slate-800 flex items-center gap-2 bg-slate-900/40">
          <Link class="w-4 h-4 text-indigo-400" />
          <h3 class="text-xs font-semibold text-white uppercase tracking-wider">Foreign Keys</h3>
        </div>

        <div v-if="structure.foreign_keys.length > 0" class="p-4 space-y-3 font-mono text-xs">
          <div
            v-for="fk in structure.foreign_keys"
            :key="fk.name"
            class="p-3 rounded-lg bg-slate-950 border border-slate-800 space-y-1"
          >
            <div class="flex items-center justify-between text-slate-300">
              <span class="font-bold text-white">{{ fk.columns.join(', ') }}</span>
              <span class="text-slate-500 text-[11px]">&rarr;</span>
              <span class="text-indigo-400 font-bold">{{ fk.table }} ({{ fk.key.join(', ') }})</span>
            </div>
            <div class="text-[10px] text-slate-500 flex items-center justify-between pt-1">
              <span>Constraint: {{ fk.name }}</span>
              <span v-if="fk.on_delete">ON DELETE {{ fk.on_delete }}</span>
            </div>
          </div>
        </div>

        <div v-else class="p-8 text-center text-xs text-slate-500 font-mono">
          No foreign keys defined
        </div>
      </div>

      <!-- Indexes -->
      <div class="bg-slate-900/80 rounded-xl border border-slate-800 overflow-hidden">
        <div class="px-4 py-3 border-b border-slate-800 flex items-center gap-2 bg-slate-900/40">
          <Bookmark class="w-4 h-4 text-sky-400" />
          <h3 class="text-xs font-semibold text-white uppercase tracking-wider">Indexes</h3>
        </div>

        <div v-if="structure.indexes.length > 0" class="p-4 space-y-3 font-mono text-xs">
          <div
            v-for="idx in structure.indexes"
            :key="idx.name"
            class="p-3 rounded-lg bg-slate-950 border border-slate-800 flex items-center justify-between"
          >
            <div>
              <p class="font-bold text-white">{{ idx.name }}</p>
              <p class="text-[11px] text-slate-400 mt-0.5">Columns: {{ idx.columns.join(', ') }}</p>
            </div>
            <span
              v-if="idx.unique"
              class="px-2 py-0.5 rounded text-[10px] font-bold bg-sky-500/10 text-sky-400 border border-sky-500/30 uppercase"
            >
              UNIQUE
            </span>
          </div>
        </div>

        <div v-else class="p-8 text-center text-xs text-slate-500 font-mono">
          No additional indexes defined
        </div>
      </div>
    </div>
  </div>
</template>
