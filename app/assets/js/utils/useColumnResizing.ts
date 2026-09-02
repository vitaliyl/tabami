import { ref, watch, onUnmounted, type Ref } from 'vue';

export interface ColumnResizingOptions {
  storageKey?: string | Ref<string | null> | (() => string | null);
  defaultWidth?: number;
  minWidth?: number;
  maxWidth?: number;
}

export function useColumnResizing(options: ColumnResizingOptions = {}) {
  const defaultBaseWidth = options.defaultWidth ?? 160;
  const minWidth = options.minWidth ?? 70;
  const maxWidth = options.maxWidth ?? 1200;

  const columnWidths = ref<Record<string, number>>({});
  const resizingCol = ref<string | null>(null);

  function getStorageKey(): string | null {
    if (!options.storageKey) return null;
    if (typeof options.storageKey === 'function') return options.storageKey();
    if (typeof options.storageKey === 'string') return options.storageKey;
    return options.storageKey.value;
  }

  function loadSavedWidths() {
    const key = getStorageKey();
    if (!key) {
      columnWidths.value = {};
      return;
    }

    try {
      const saved = localStorage.getItem(key);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed === 'object') {
          columnWidths.value = parsed;
          return;
        }
      }
    } catch (e) {
      // Ignore JSON parse or storage errors
    }
    columnWidths.value = {};
  }

  function saveWidths() {
    const key = getStorageKey();
    if (!key) return;

    try {
      if (Object.keys(columnWidths.value).length === 0) {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, JSON.stringify(columnWidths.value));
      }
    } catch (e) {
      // Ignore storage errors
    }
  }

  if (options.storageKey) {
    if (typeof options.storageKey === 'function' || typeof options.storageKey === 'object') {
      watch(
        () => (typeof options.storageKey === 'function' ? (options.storageKey as Function)() : (options.storageKey as Ref<string | null>).value),
        () => {
          loadSavedWidths();
        },
        { immediate: true }
      );
    } else {
      loadSavedWidths();
    }
  }

  function getDefaultWidth(colName: string, colType: string = ''): number {
    const name = colName.toLowerCase();
    const type = colType.toLowerCase();

    if (name === 'id') return 90;
    if (name.endsWith('_id') || name.endsWith('id')) return 110;

    if (type.includes('bool') || type.includes('bit') || name.startsWith('is_') || name.startsWith('has_')) {
      return 100;
    }

    if (type.includes('timestamp') || type.includes('datetime') || name.includes('created_at') || name.includes('updated_at') || name.includes('deleted_at')) {
      return 180;
    }
    if (type.includes('date') || type.includes('time')) {
      return 130;
    }

    if (type.includes('int') || type.includes('serial') || type.includes('decimal') || type.includes('numeric') || type.includes('float') || type.includes('double') || type.includes('real')) {
      return 120;
    }

    if (type.includes('json') || name.includes('json') || name.includes('data') || name.includes('meta') || name.includes('payload') || name.includes('config')) {
      return 230;
    }

    if (type.includes('text') || name.includes('description') || name.includes('comment') || name.includes('message') || name.includes('body') || name.includes('summary') || name.includes('url')) {
      return 250;
    }

    return Math.max(140, Math.min(220, colName.length * 10 + 60));
  }

  function getColumnWidth(colName: string, colType: string = ''): number {
    if (columnWidths.value[colName] !== undefined) {
      return columnWidths.value[colName];
    }
    return getDefaultWidth(colName, colType);
  }

  function setColumnWidth(colName: string, width: number) {
    const clamped = Math.max(minWidth, Math.min(maxWidth, Math.round(width)));
    columnWidths.value = {
      ...columnWidths.value,
      [colName]: clamped,
    };
    saveWidths();
  }

  let cleanupDragListeners: (() => void) | null = null;

  function startResize(colName: string, event: MouseEvent, colType: string = '') {
    event.preventDefault();
    event.stopPropagation();

    if (cleanupDragListeners) {
      cleanupDragListeners();
    }

    const startX = event.clientX;
    const startWidth = getColumnWidth(colName, colType);
    resizingCol.value = colName;

    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';

    function onMouseMove(e: MouseEvent) {
      const deltaX = e.clientX - startX;
      const newWidth = Math.max(minWidth, Math.min(maxWidth, Math.round(startWidth + deltaX)));
      columnWidths.value = {
        ...columnWidths.value,
        [colName]: newWidth,
      };
    }

    function onMouseUp() {
      resizingCol.value = null;
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
      saveWidths();

      if (cleanupDragListeners) {
        cleanupDragListeners();
        cleanupDragListeners = null;
      }
    }

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);

    cleanupDragListeners = () => {
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };
  }

  function autoFitColumn(colName: string, sampleRows: Record<string, any>[] = [], colType: string = '') {
    let maxCharLen = colName.length + (colType ? colType.length / 2 : 0) + 4;

    const sampleLimit = Math.min(sampleRows.length, 60);
    for (let i = 0; i < sampleLimit; i++) {
      const val = sampleRows[i]?.[colName];
      if (val !== null && val !== undefined) {
        let strVal = '';
        if (typeof val === 'object') {
          try {
            strVal = JSON.stringify(val);
          } catch {
            strVal = String(val);
          }
        } else {
          strVal = String(val);
        }
        if (strVal.length > maxCharLen) {
          maxCharLen = Math.min(strVal.length, 55);
        }
      }
    }

    const estimatedWidth = Math.max(minWidth, Math.min(maxWidth, Math.round(maxCharLen * 8.5) + 45));
    setColumnWidth(colName, estimatedWidth);
  }

  function resetColumnWidth(colName: string) {
    if (columnWidths.value[colName] !== undefined) {
      const copy = { ...columnWidths.value };
      delete copy[colName];
      columnWidths.value = copy;
      saveWidths();
    }
  }

  function resetAllWidths() {
    columnWidths.value = {};
    saveWidths();
  }

  onUnmounted(() => {
    if (cleanupDragListeners) {
      cleanupDragListeners();
    }
  });

  return {
    columnWidths,
    resizingCol,
    getColumnWidth,
    setColumnWidth,
    startResize,
    autoFitColumn,
    resetColumnWidth,
    resetAllWidths,
    getDefaultWidth,
  };
}
