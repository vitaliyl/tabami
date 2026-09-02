export interface TableItem {
  name: string;
  type: 'table' | 'view';
  schema: string;
  estimated_rows?: number;
}

export interface DomainColorTheme {
  bg: string;
  text: string;
  border: string;
  badge: string;
  accent: string;
  gradient: string;
}

export interface DomainGroup {
  id: string;
  name: string;
  description: string;
  iconName: string;
  color: DomainColorTheme;
  tables: TableItem[];
  tableCount: number;
  totalEstimatedRows: number;
  rootTables: string[];
}

export const DOMAIN_COLOR_PALETTES: Record<string, DomainColorTheme> = {
  ruby: {
    bg: 'bg-rose-500/10',
    text: 'text-rose-700 dark:text-ruby-400',
    border: 'border-rose-500/30',
    badge: 'bg-rose-50 text-rose-700 border-rose-200 dark:bg-ruby-950 dark:text-ruby-300 dark:border-ruby-800/80',
    accent: 'text-rose-600 dark:text-ruby-400',
    gradient: 'from-rose-600/20 to-ruby-500/10',
  },
  matcha: {
    bg: 'bg-emerald-500/10',
    text: 'text-emerald-700 dark:text-matcha-400',
    border: 'border-emerald-500/30',
    badge: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-matcha-950 dark:text-matcha-300 dark:border-matcha-800/80',
    accent: 'text-emerald-600 dark:text-matcha-400',
    gradient: 'from-emerald-600/20 to-teal-500/10',
  },
  aizome: {
    bg: 'bg-indigo-500/10',
    text: 'text-indigo-700 dark:text-aizome-400',
    border: 'border-indigo-500/30',
    badge: 'bg-indigo-50 text-indigo-700 border-indigo-200 dark:bg-aizome-950 dark:text-aizome-300 dark:border-aizome-800/80',
    accent: 'text-indigo-600 dark:text-aizome-400',
    gradient: 'from-indigo-600/20 to-blue-500/10',
  },
  yamabuki: {
    bg: 'bg-amber-500/10',
    text: 'text-amber-700 dark:text-yamabuki-400',
    border: 'border-amber-500/30',
    badge: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-yamabuki-950 dark:text-yamabuki-300 dark:border-yamabuki-800/80',
    accent: 'text-amber-600 dark:text-yamabuki-400',
    gradient: 'from-amber-600/20 to-yellow-500/10',
  },
  violet: {
    bg: 'bg-purple-500/10',
    text: 'text-purple-700 dark:text-purple-400',
    border: 'border-purple-500/30',
    badge: 'bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-950 dark:text-purple-300 dark:border-purple-800/80',
    accent: 'text-purple-600 dark:text-purple-400',
    gradient: 'from-purple-600/20 to-pink-500/10',
  },
  blue: {
    bg: 'bg-blue-500/10',
    text: 'text-blue-700 dark:text-blue-400',
    border: 'border-blue-500/30',
    badge: 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800/80',
    accent: 'text-blue-600 dark:text-blue-400',
    gradient: 'from-blue-600/20 to-sky-500/10',
  },
  cyan: {
    bg: 'bg-teal-500/10',
    text: 'text-teal-400',
    border: 'border-teal-500/30',
    badge: 'bg-teal-950 text-teal-300 border-teal-800/80',
    accent: 'text-teal-400',
    gradient: 'from-teal-600/20 to-cyan-500/10',
  },
  slate: {
    bg: 'bg-sumi-800/40',
    text: 'text-slate-400',
    border: 'border-sumi-700/60',
    badge: 'bg-sumi-900 text-slate-400 border-sumi-700',
    accent: 'text-slate-400',
    gradient: 'from-sumi-800/30 to-sumi-900/10',
  },
  general: {
    bg: 'bg-sumi-800/30',
    text: 'text-slate-300',
    border: 'border-sumi-750',
    badge: 'bg-sumi-950 text-slate-400 border-sumi-800',
    accent: 'text-slate-300',
    gradient: 'from-sumi-850/40 to-sumi-900/10',
  }
};

DOMAIN_COLOR_PALETTES.events = DOMAIN_COLOR_PALETTES.matcha;
DOMAIN_COLOR_PALETTES.ledger = DOMAIN_COLOR_PALETTES.violet;
DOMAIN_COLOR_PALETTES.bot = DOMAIN_COLOR_PALETTES.yamabuki;
DOMAIN_COLOR_PALETTES.auth = DOMAIN_COLOR_PALETTES.blue;
DOMAIN_COLOR_PALETTES.integrations = DOMAIN_COLOR_PALETTES.cyan;
DOMAIN_COLOR_PALETTES.ecommerce = DOMAIN_COLOR_PALETTES.matcha;
DOMAIN_COLOR_PALETTES.system = DOMAIN_COLOR_PALETTES.slate;
DOMAIN_COLOR_PALETTES.dynamic = DOMAIN_COLOR_PALETTES.aizome;

/**
 * Classifies a flat list of tables into logical domain groups
 * using heuristic naming patterns and common prefixes.
 */
export function classifyTablesIntoDomains(tables: TableItem[]): DomainGroup[] {
  if (!tables || tables.length === 0) return [];

  const assigned = new Set<string>();
  const groups: DomainGroup[] = [];

  const toTitleCase = (str: string) =>
    str.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

  // 1. Events Domain Detection
  const isEventTable = (name: string) =>
    name.startsWith('event_') ||
    name === 'sports_events' ||
    name === 'recurring_slots' ||
    name === 'substitute_requests' ||
    name.startsWith('group_priority_') ||
    name.startsWith('event_priority_') ||
    name.startsWith('group_voting_') ||
    name.startsWith('game_finder_');

  const eventTables = tables.filter((t) => !assigned.has(t.name) && isEventTable(t.name));
  if (eventTables.length > 0) {
    eventTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'events',
      name: 'Events & Participation',
      description: 'Event groups, scheduling, recurring slots, RSVPs, subgroups & voting',
      iconName: 'CalendarDays',
      color: DOMAIN_COLOR_PALETTES.events,
      tables: eventTables,
      tableCount: eventTables.length,
      totalEstimatedRows: eventTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: eventTables
        .filter((t) => ['event_groups', 'sports_events', 'event_members'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 2. Ledger & Billing Domain
  const isLedgerTable = (name: string) => name.startsWith('ledger_');
  const ledgerTables = tables.filter((t) => !assigned.has(t.name) && isLedgerTable(t.name));
  if (ledgerTables.length > 0) {
    ledgerTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'ledger',
      name: 'Ledger & Billing',
      description: 'Double-entry ledger accounts, charges, payments, settlements & holdings',
      iconName: 'CreditCard',
      color: DOMAIN_COLOR_PALETTES.ledger,
      tables: ledgerTables,
      tableCount: ledgerTables.length,
      totalEstimatedRows: ledgerTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: ledgerTables
        .filter((t) => ['ledger_accounts', 'ledger_charges'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 3. Telegram Bot Domain
  const isBotTable = (name: string) => name.startsWith('bot_');
  const botTables = tables.filter((t) => !assigned.has(t.name) && isBotTable(t.name));
  if (botTables.length > 0) {
    botTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'bot',
      name: 'Telegram Bot Store',
      description: 'Bot identities, registrations, chat bindings, conversations & event cards',
      iconName: 'Bot',
      color: DOMAIN_COLOR_PALETTES.bot,
      tables: botTables,
      tableCount: botTables.length,
      totalEstimatedRows: botTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: botTables
        .filter((t) => ['bot_identities', 'bot_registrations'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 4. Integrations & Bridges
  const isIntegrationTable = (name: string) =>
    name.startsWith('integration_') || name === 'owner_entitlements';
  const integrationTables = tables.filter((t) => !assigned.has(t.name) && isIntegrationTable(t.name));
  if (integrationTables.length > 0) {
    integrationTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'integrations',
      name: 'Integrations & Bridges',
      description: 'Cross-domain bridges, notification intents, external user links & webhooks',
      iconName: 'Plug',
      color: DOMAIN_COLOR_PALETTES.integrations,
      tables: integrationTables,
      tableCount: integrationTables.length,
      totalEstimatedRows: integrationTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: integrationTables
        .filter((t) => ['integration_member_accounts', 'integration_external_user_links'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 5. Auth Domain
  const isAuthTable = (name: string) =>
    ['user', 'users', 'session', 'sessions', 'account', 'accounts', 'verification', 'verifications'].includes(name) ||
    name.startsWith('oauth_') ||
    name.startsWith('auth_');
  const authTables = tables.filter((t) => !assigned.has(t.name) && isAuthTable(t.name));
  if (authTables.length > 0) {
    authTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'auth',
      name: 'Authentication (Identity)',
      description: 'User accounts, active sessions, OAuth tokens and email verifications',
      iconName: 'ShieldCheck',
      color: DOMAIN_COLOR_PALETTES.auth,
      tables: authTables,
      tableCount: authTables.length,
      totalEstimatedRows: authTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: authTables
        .filter((t) => ['user', 'users', 'account', 'accounts'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 6. Audit & System Domain
  const isSystemTable = (name: string) =>
    name.startsWith('audit_') ||
    name.startsWith('schema_migrations') ||
    ['ar_internal_metadata', 'spatial_ref_sys', 'flyway_schema_history'].includes(name);
  const systemTables = tables.filter((t) => !assigned.has(t.name) && isSystemTable(t.name));
  if (systemTables.length > 0) {
    systemTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'system',
      name: 'Audit & System',
      description: 'Audit logs, database schema migrations & system metadata tables',
      iconName: 'History',
      color: DOMAIN_COLOR_PALETTES.system,
      tables: systemTables,
      tableCount: systemTables.length,
      totalEstimatedRows: systemTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: systemTables.map((t) => t.name),
    });
  }

  // 7. Demo / eCommerce Store Domain
  const isEcommerceTable = (name: string) =>
    ['customers', 'products', 'orders', 'order_items', 'categories'].includes(name);
  const ecommerceTables = tables.filter((t) => !assigned.has(t.name) && isEcommerceTable(t.name));
  if (ecommerceTables.length > 0) {
    ecommerceTables.forEach((t) => assigned.add(t.name));
    groups.push({
      id: 'ecommerce',
      name: 'Store & Catalog',
      description: 'E-commerce customers, orders, inventory products, categories & order items',
      iconName: 'ShoppingBag',
      color: DOMAIN_COLOR_PALETTES.ecommerce,
      tables: ecommerceTables,
      tableCount: ecommerceTables.length,
      totalEstimatedRows: ecommerceTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: ecommerceTables
        .filter((t) => ['customers', 'orders', 'products'].includes(t.name))
        .map((t) => t.name),
    });
  }

  // 8. Generic Prefix Clustering for other tables
  const remainingTables = tables.filter((t) => !assigned.has(t.name));
  const prefixGroups = new Map<string, TableItem[]>();

  remainingTables.forEach((table) => {
    const parts = table.name.split('_');
    if (parts.length > 1) {
      const prefix = parts[0];
      if (!prefixGroups.has(prefix)) prefixGroups.set(prefix, []);
      prefixGroups.get(prefix)!.push(table);
    }
  });

  // Only promote prefix groups with >= 2 tables
  prefixGroups.forEach((groupTables, prefix) => {
    if (groupTables.length >= 2) {
      groupTables.forEach((t) => assigned.add(t.name));
      const groupName = `${toTitleCase(prefix)} Domain`;
      groups.push({
        id: `prefix_${prefix}`,
        name: groupName,
        description: `Tables belonging to the ${prefix} subsystem`,
        iconName: 'Layers',
        color: DOMAIN_COLOR_PALETTES.dynamic,
        tables: groupTables,
        tableCount: groupTables.length,
        totalEstimatedRows: groupTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
        rootTables: groupTables.slice(0, 2).map((t) => t.name),
      });
    }
  });

  // 9. General / Uncategorized Fallback
  const unassignedTables = tables.filter((t) => !assigned.has(t.name));
  if (unassignedTables.length > 0) {
    groups.push({
      id: 'general',
      name: 'General & Standalone',
      description: 'Standalone and uncategorized tables in this schema',
      iconName: 'Database',
      color: DOMAIN_COLOR_PALETTES.general,
      tables: unassignedTables,
      tableCount: unassignedTables.length,
      totalEstimatedRows: unassignedTables.reduce((acc, t) => acc + (t.estimated_rows || 0), 0),
      rootTables: unassignedTables.map((t) => t.name),
    });
  }

  return groups;
}
