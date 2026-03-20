// Mirrors Swift models: HapticPattern, SessionSettings, SessionProfile, Session, SessionSequence

// Re-export AppTheme so consumers can import from types
export type { AppTheme } from '../services/theme';

export type HapticPattern = 'notification' | 'click' | 'success' | 'directionUp' | 'retry';

export const HAPTIC_PATTERN_DISPLAY: Record<HapticPattern, string> = {
  notification: 'Strong Tap',
  click: 'Light Tap',
  success: 'Confirmation',
  directionUp: 'Encouraging',
  retry: 'Gentle Nudge',
};

export const HAPTIC_PATTERNS: HapticPattern[] = [
  'notification',
  'click',
  'success',
  'directionUp',
  'retry',
];

export type HapticMode = 'randomized' | 'consistent' | 'morse';

export type SessionEndCondition =
  | { type: 'unlimited' }
  | { type: 'afterCount'; count: number }
  | { type: 'afterDuration'; seconds: number };

export interface SessionSettings {
  hapticMode: HapticMode;
  hapticPattern: HapticPattern;
  intervalSound: string;
  completionSound: string;
  focusReminderEnabled: boolean;
  theme: import('../services/theme').AppTheme;
}

export const DEFAULT_SETTINGS: SessionSettings = {
  hapticMode: 'randomized',
  hapticPattern: 'notification',
  intervalSound: 'none',
  completionSound: 'done',
  focusReminderEnabled: true,
  theme: 'coachAuthority',
};

export interface SessionProfile {
  id: string;
  name: string;
  icon: string;
  intervalSeconds: number;
  varianceSeconds: number;
  endCondition: SessionEndCondition;
  notes: string;
  hapticModeOverride?: HapticMode;
  hapticPatternOverride?: HapticPattern;
  intervalSoundOverride?: string;
  completionSoundOverride?: string;
  morseWord?: string;
  createdAt: string; // ISO date
  isTemplate: boolean;
  showOnTimer: boolean;
}

export interface Session {
  id: string;
  profileId?: string;
  profileName: string;
  startedAt: string;
  endedAt?: string;
  intervalSeconds: number;
  varianceSeconds: number;
  reminderCount: number;
  wasCancelled: boolean;
  sequenceId?: string;
  sequenceIndex?: number;
  sequenceName?: string;
}

export type SequenceTransition = 'autoAdvance' | 'manual';

export interface SequenceStep {
  id: string;
  profile: SessionProfile;
  endCondition: SessionEndCondition;
}

export interface SessionSequence {
  id: string;
  name: string;
  icon: string;
  steps: SequenceStep[];
  transition: SequenceTransition;
  countdownSeconds: number;
  createdAt: string;
}

export type PremiumFeature =
  | 'unlimitedPresets'
  | 'allTemplates'
  | 'consistentHaptics'
  | 'varyTiming'
  | 'presetOverrides'
  | 'morseHaptics'
  | 'fullHistory'
  | 'allThemes'
  | 'sessionBuilder';

// Helper functions

export function formatInterval(seconds: number): string {
  if (seconds >= 60) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return s > 0 ? `${m}m ${s}s` : `${m}m`;
  }
  return `${seconds}s`;
}

export function formatEndCondition(condition: SessionEndCondition): string {
  switch (condition.type) {
    case 'unlimited':
      return 'No limit';
    case 'afterCount':
      return `${condition.count} reminders`;
    case 'afterDuration':
      if (condition.seconds >= 3600) return `${Math.floor(condition.seconds / 3600)} hr`;
      return `${Math.floor(condition.seconds / 60)} min`;
  }
}

export function formatDuration(startedAt: string, endedAt: string): string {
  const dur = (new Date(endedAt).getTime() - new Date(startedAt).getTime()) / 1000;
  const m = Math.floor(dur / 60);
  const s = Math.floor(dur % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function resolvedHapticMode(profile: SessionProfile, defaults: SessionSettings): HapticMode {
  return profile.hapticModeOverride ?? defaults.hapticMode;
}

export function resolvedHapticPattern(profile: SessionProfile, defaults: SessionSettings): HapticPattern {
  return profile.hapticPatternOverride ?? defaults.hapticPattern;
}

export function resolvedIntervalSound(profile: SessionProfile, defaults: SessionSettings): string {
  return profile.intervalSoundOverride ?? defaults.intervalSound;
}

export function resolvedCompletionSound(profile: SessionProfile, defaults: SessionSettings): string {
  return profile.completionSoundOverride ?? defaults.completionSound;
}

export function resolvedMorseWord(profile: SessionProfile): string {
  const word = (profile.morseWord ?? '').trim();
  if (word) return word.toUpperCase();
  const alpha = profile.name.replace(/[^a-zA-Z]/g, '');
  return alpha.slice(0, 4).toUpperCase();
}

// Free templates
export const FREE_TEMPLATE_NAMES = new Set(['Strength Circuit', 'Posture Check']);
