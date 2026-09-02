import { ref, computed } from 'vue';

export type ThemeMode = 'dark' | 'matcha' | 'light';

const THEME_STORAGE_KEY = 'tabami_theme';

function getInitialTheme(): ThemeMode {
  try {
    const saved = localStorage.getItem(THEME_STORAGE_KEY) as ThemeMode | null;
    if (saved === 'dark' || saved === 'matcha' || saved === 'light') {
      return saved;
    }
  } catch (e) {
    // localStorage might be unavailable
  }
  return 'dark';
}

const currentTheme = ref<ThemeMode>(getInitialTheme());

export function applyTheme(theme: ThemeMode) {
  currentTheme.value = theme;
  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (e) {}

  if (typeof document !== 'undefined') {
    const root = document.documentElement;
    root.classList.remove('dark', 'light', 'matcha');
    root.classList.add(theme);
  }
}

// Immediate initial execution on module load
if (typeof document !== 'undefined') {
  applyTheme(currentTheme.value);
}

export function useTheme() {
  const isDark = computed(() => currentTheme.value === 'dark');
  const isMatcha = computed(() => currentTheme.value === 'matcha');
  const isLight = computed(() => currentTheme.value === 'light');

  const themeLabel = computed(() => {
    switch (currentTheme.value) {
      case 'matcha':
        return 'Matcha Earth';
      case 'light':
        return 'Washi Light';
      case 'dark':
      default:
        return 'Sumi Dark';
    }
  });

  const nextThemeTitle = computed(() => {
    switch (currentTheme.value) {
      case 'dark':
        return 'Theme: Sumi (Dark) • Click for Matcha (Muted Earth)';
      case 'matcha':
        return 'Theme: Matcha (Muted Earth) • Click for Washi (Light)';
      case 'light':
      default:
        return 'Theme: Washi (Light) • Click for Sumi (Dark)';
    }
  });

  function toggleTheme() {
    if (currentTheme.value === 'dark') {
      applyTheme('matcha');
    } else if (currentTheme.value === 'matcha') {
      applyTheme('light');
    } else {
      applyTheme('dark');
    }
  }

  function setTheme(mode: ThemeMode) {
    applyTheme(mode);
  }

  return {
    theme: currentTheme,
    isDark,
    isMatcha,
    isLight,
    themeLabel,
    nextThemeTitle,
    toggleTheme,
    setTheme,
  };
}
