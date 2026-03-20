import { Platform } from 'react-native';

// src/services/theme.ts

// ---------------------------------------------------------------------------
// Theme types & definitions
// ---------------------------------------------------------------------------

export type AppTheme =
  | 'coachAuthority'
  | 'activeRecovery'
  | 'darkAcademia'
  | 'mysticGrove'
  | 'runestone'
  | 'dailyRitual';

interface ThemeColors {
  primary: string;
  accent: string;
  background: string;
  secondaryText: string;
  success: string;
  cardBackground: string;
  pillBackground: string;
  onAccent: string;
  destructive: string;
}

interface ThemeEntry {
  displayName: string;
  colors: ThemeColors;
}

export const THEMES: Record<AppTheme, ThemeEntry> = {
  coachAuthority: {
    displayName: "Coach's Authority",
    colors: {
      primary: '#1B2D4F',
      accent: '#D4932A',
      background: '#F5F0EB',
      secondaryText: '#7A8199',
      success: '#2E8B57',
      cardBackground: '#FFFFFF',
      pillBackground: '#E8E3DD',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
  activeRecovery: {
    displayName: 'Active Recovery',
    colors: {
      primary: '#0A5E5C',
      accent: '#E07A5F',
      background: '#F7F5F2',
      secondaryText: '#6B8A89',
      success: '#4A9B7F',
      cardBackground: '#FFFFFF',
      pillBackground: '#E5EDEC',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
  darkAcademia: {
    displayName: 'Dark Academia',
    colors: {
      primary: '#2C1810',
      accent: '#8B4513',
      background: '#F2E8DC',
      secondaryText: '#8C7B6B',
      success: '#5E8C61',
      cardBackground: '#FAF5EE',
      pillBackground: '#E6D9CA',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
  mysticGrove: {
    displayName: 'Mystic Grove',
    colors: {
      primary: '#1A3A3A',
      accent: '#4ECDC4',
      background: '#E8F4F2',
      secondaryText: '#6A9E9A',
      success: '#3EAF8A',
      cardBackground: '#F5FDFB',
      pillBackground: '#D5EAE7',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
  runestone: {
    displayName: 'Runestone',
    colors: {
      primary: '#3B3236',
      accent: '#C4956A',
      background: '#F0EDEB',
      secondaryText: '#8A7E82',
      success: '#6B9E6B',
      cardBackground: '#FAF8F7',
      pillBackground: '#E3DFDD',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
  dailyRitual: {
    displayName: 'Daily Ritual',
    colors: {
      primary: '#2D2B3D',
      accent: '#7C6BC4',
      background: '#F0EEF6',
      secondaryText: '#8986A0',
      success: '#5E9B76',
      cardBackground: '#F9F7FF',
      pillBackground: '#E2DFEE',
      onAccent: '#FFFFFF',
      destructive: '#8B3A3A',
    },
  },
};

export const THEME_KEYS: AppTheme[] = [
  'coachAuthority',
  'activeRecovery',
  'darkAcademia',
  'mysticGrove',
  'runestone',
  'dailyRitual',
];

// ---------------------------------------------------------------------------
// Mutable colors object — all existing `colors.primary` references keep working
// ---------------------------------------------------------------------------

let currentThemeKey: AppTheme = 'coachAuthority';

export const colors: ThemeColors = { ...THEMES.coachAuthority.colors };

/** Apply a theme by mutating the shared `colors` object in-place. */
export function setTheme(themeKey: AppTheme): void {
  currentThemeKey = themeKey;
  const src = THEMES[themeKey].colors;
  (Object.keys(src) as (keyof ThemeColors)[]).forEach((k) => {
    (colors as unknown as Record<string, string>)[k] = src[k];
  });
}

/** Return the currently active theme key. */
export function getThemeKey(): AppTheme {
  return currentThemeKey;
}

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const fontSize = {
  xs: 9,
  sm: 13,
  md: 15,
  lg: 17,
  xl: 22,
  xxl: 28,
  timer: 56,
};

// Top padding to clear the hamburger menu button on all screens
export const SCREEN_TOP_PAD = Platform.OS === 'ios' ? 108 : 96;
