import React, { useState, useRef, useCallback, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  AppState,
  Dimensions,
  Platform,
} from 'react-native';
import Slider from '@react-native-community/slider';
import { colors, SCREEN_TOP_PAD } from '../services/theme';
import { TimerService, TimerState } from '../services/TimerService';
import { playHaptic, playRandomHaptic } from '../services/HapticService';
import { playMorse } from '../services/MorsePlayer';
import {
  SessionProfile,
  SessionSettings,
  HapticMode,
  SessionEndCondition,
  DEFAULT_SETTINGS,
  formatInterval,
  formatEndCondition,
  resolvedHapticMode,
  resolvedHapticPattern,
  resolvedMorseWord,
} from '../models/types';
import { v4 as uuid } from '../models/uuid';
import * as Storage from '../services/StorageService';
import { useAppContext } from '../services/AppContext';
import { PROFILE_TEMPLATES } from '../models/templates';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ScreenPhase = 'idle' | 'active' | 'complete';

interface Props {
  profile?: SessionProfile;
  onSessionEnd?: () => void;
}

// ---------------------------------------------------------------------------
// Interval presets (pill buttons)
// ---------------------------------------------------------------------------

interface IntervalOption {
  label: string;
  seconds: number | null; // null = custom
}

const INTERVAL_OPTIONS: IntervalOption[] = [
  { label: '30s', seconds: 30 },
  { label: '1m', seconds: 60 },
  { label: '2m', seconds: 120 },
  { label: '5m', seconds: 300 },
  { label: '10m', seconds: 600 },
  { label: 'Custom', seconds: null },
];

// ---------------------------------------------------------------------------
// End-condition presets
// ---------------------------------------------------------------------------

interface EndOption {
  label: string;
  condition: SessionEndCondition;
}

const END_OPTIONS: EndOption[] = [
  { label: '\u221E', condition: { type: 'unlimited' } },
  { label: '5\u00D7', condition: { type: 'afterCount', count: 5 } },
  { label: '10\u00D7', condition: { type: 'afterCount', count: 10 } },
  { label: '15 min', condition: { type: 'afterDuration', seconds: 900 } },
  { label: '30 min', condition: { type: 'afterDuration', seconds: 1800 } },
  { label: '1 hr', condition: { type: 'afterDuration', seconds: 3600 } },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatTimer(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

function endConditionsEqual(a: SessionEndCondition, b: SessionEndCondition): boolean {
  if (a.type !== b.type) return false;
  if (a.type === 'afterCount' && b.type === 'afterCount') return a.count === b.count;
  if (a.type === 'afterDuration' && b.type === 'afterDuration') return a.seconds === b.seconds;
  return true;
}

function totalForCondition(
  endCondition: SessionEndCondition,
  intervalSeconds: number,
): number | null {
  switch (endCondition.type) {
    case 'unlimited':
      return null;
    case 'afterCount':
      return endCondition.count;
    case 'afterDuration':
      return intervalSeconds > 0
        ? Math.ceil(endCondition.seconds / intervalSeconds)
        : null;
  }
}

function totalSecondsForCondition(endCondition: SessionEndCondition): number | null {
  switch (endCondition.type) {
    case 'unlimited':
      return null;
    case 'afterCount':
      return null;
    case 'afterDuration':
      return endCondition.seconds;
  }
}

// ---------------------------------------------------------------------------
// Preset chip icons (SF Symbol names mapped to simple Unicode/emoji fallbacks)
// ---------------------------------------------------------------------------

const ICON_MAP: Record<string, string> = {
  bolt: '\u26A1',
  horse: '\uD83D\uDC0E',
  dumbbell: '\uD83C\uDFCB',
  accessibility: '\u267F',
  body: '\uD83E\uDDD8',
  fitness: '\uD83E\uDDD8',
  timer: '\u23F1',
  default: '\u23F1',
};

function iconForProfile(icon?: string): string {
  if (!icon) return ICON_MAP.default;
  return ICON_MAP[icon] ?? ICON_MAP.default;
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function TimerScreen({ profile, onSessionEnd }: Props) {
  // -- context (reactive) ---------------------------------------------------
  const ctx = useAppContext();
  const savedProfiles = ctx.profiles;
  const settings = ctx.settings;

  // -- timer engine ---------------------------------------------------------
  const [timerState, setTimerState] = useState<TimerState>({
    isRunning: false,
    elapsedSeconds: 0,
    reminderCount: 0,
    secondsUntilNextBuzz: 0,
    isComplete: false,
  });

  // -- UI state -------------------------------------------------------------
  const [phase, setPhase] = useState<ScreenPhase>('idle');
  const [selectedProfileId, setSelectedProfileId] = useState<string | null>(
    profile?.id ?? null,
  );
  const [intervalSeconds, setIntervalSeconds] = useState(
    profile?.intervalSeconds ?? 60,
  );
  const [customInterval, setCustomInterval] = useState(90);
  const [isCustomInterval, setIsCustomInterval] = useState(false);
  const [varyEnabled, setVaryEnabled] = useState(
    (profile?.varianceSeconds ?? 0) > 0,
  );
  const [varianceSeconds, setVarianceSeconds] = useState(
    profile?.varianceSeconds ?? 15,
  );
  const [endCondition, setEndCondition] = useState<SessionEndCondition>(
    profile?.endCondition ?? { type: 'unlimited' },
  );

  // -- completion stats -----------------------------------------------------
  const [completionStats, setCompletionStats] = useState({
    duration: '',
    reminders: 0,
    presetName: 'Quick Timer',
  });

  // -- refs -----------------------------------------------------------------
  const timerRef = useRef<TimerService | null>(null);
  const morseSignalRef = useRef({ cancelled: false });
  const sessionStartRef = useRef<Date | null>(null);

  // -- background / foreground handling -------------------------------------
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        timerRef.current?.resumeFromBackground();
      }
    });
    return () => sub.remove();
  }, []);

  // -- derived: active profile object ---------------------------------------
  const activeProfile: SessionProfile | undefined = useMemo(() => {
    if (!selectedProfileId) return undefined;
    if (profile && profile.id === selectedProfileId) return profile;
    return savedProfiles.find((p) => p.id === selectedProfileId)
      ?? PROFILE_TEMPLATES.find((p) => p.id === selectedProfileId);
  }, [selectedProfileId, profile, savedProfiles]);

  // -- sync UI state when a preset chip is tapped ---------------------------
  const selectProfile = useCallback((p: SessionProfile | null) => {
    if (!p) {
      setSelectedProfileId(null);
      setIntervalSeconds(60);
      setIsCustomInterval(false);
      setVaryEnabled(false);
      setVarianceSeconds(15);
      setEndCondition({ type: 'unlimited' });
      return;
    }
    setSelectedProfileId(p.id);
    setIntervalSeconds(p.intervalSeconds);
    setIsCustomInterval(false);
    setVaryEnabled(p.varianceSeconds > 0);
    setVarianceSeconds(p.varianceSeconds || 15);
    setEndCondition(p.endCondition);
  }, []);

  // -- react to profile prop changes (from Presets screen selection) --------
  useEffect(() => {
    if (profile) {
      selectProfile(profile);
    }
  }, [profile, selectProfile]);

  // -- preset chips (Quick + saved/template profiles with showOnTimer) -----
  const presetChips = useMemo(() => {
    const chips: { id: string | null; label: string; icon: string; profile: SessionProfile | null }[] = [
      { id: null, label: 'Quick', icon: ICON_MAP.bolt, profile: null },
    ];
    // User profiles
    const visible = savedProfiles.filter((p) => p.showOnTimer);
    for (const p of visible) {
      chips.push({ id: p.id, label: p.name, icon: iconForProfile(p.icon), profile: p });
    }
    // Templates (that aren't already in user profiles)
    const userNames = new Set(savedProfiles.map((p) => p.name));
    for (const t of PROFILE_TEMPLATES) {
      if (t.showOnTimer && !userNames.has(t.name)) {
        chips.push({ id: t.id, label: t.name, icon: iconForProfile(t.icon), profile: t });
      }
    }
    return chips;
  }, [savedProfiles]);

  // -- effective values for timer start -------------------------------------
  const effectiveInterval = isCustomInterval ? customInterval : intervalSeconds;
  const effectiveVariance = varyEnabled ? varianceSeconds : 0;

  // -- haptic playback callback ---------------------------------------------
  const handleBuzz = useCallback(() => {
    const mode: HapticMode = activeProfile
      ? resolvedHapticMode(activeProfile, settings)
      : settings.hapticMode;

    if (mode === 'morse') {
      const word = activeProfile ? resolvedMorseWord(activeProfile) : 'BUZZ';
      morseSignalRef.current = { cancelled: false };
      playMorse(word, morseSignalRef.current);
    } else if (mode === 'randomized') {
      playRandomHaptic();
    } else {
      const pattern = activeProfile
        ? resolvedHapticPattern(activeProfile, settings)
        : settings.hapticPattern;
      playHaptic(pattern);
    }
  }, [activeProfile, settings]);

  // -- start session --------------------------------------------------------
  const handleStart = useCallback(() => {
    morseSignalRef.current.cancelled = true;
    sessionStartRef.current = new Date();

    const timer = new TimerService((newState) => {
      setTimerState(newState);
      // Detect completion via the service's isComplete flag
      if (newState.isComplete) {
        const now = new Date();
        const dur = sessionStartRef.current
          ? formatTimer(
              Math.floor(
                (now.getTime() - sessionStartRef.current.getTime()) / 1000,
              ),
            )
          : '0:00';
        setCompletionStats({
          duration: dur,
          reminders: newState.reminderCount,
          presetName: activeProfile?.name ?? 'Quick Timer',
        });
        setPhase('complete');
      }
    });
    timerRef.current = timer;

    const ec = endCondition;
    timer.start({
      intervalSeconds: effectiveInterval,
      varianceSeconds: effectiveVariance,
      endCondition: ec,
      onInterval: handleBuzz,
      onComplete: () => {
        const now = new Date();
        Storage.addSession({
          id: uuid(),
          profileId: activeProfile?.id,
          profileName: activeProfile?.name ?? 'Quick Timer',
          startedAt: sessionStartRef.current?.toISOString() ?? now.toISOString(),
          endedAt: now.toISOString(),
          intervalSeconds: effectiveInterval,
          varianceSeconds: effectiveVariance,
          reminderCount: timer.state.reminderCount,
          wasCancelled: false,
        });
      },
    });

    setPhase('active');
  }, [effectiveInterval, effectiveVariance, endCondition, handleBuzz, activeProfile]);

  // -- cancel session -------------------------------------------------------
  const handleCancel = useCallback(() => {
    morseSignalRef.current.cancelled = true;
    const timer = timerRef.current;
    if (timer && sessionStartRef.current) {
      const now = new Date();
      Storage.addSession({
        id: uuid(),
        profileId: activeProfile?.id,
        profileName: activeProfile?.name ?? 'Quick Timer',
        startedAt: sessionStartRef.current.toISOString(),
        endedAt: now.toISOString(),
        intervalSeconds: effectiveInterval,
        varianceSeconds: effectiveVariance,
        reminderCount: timer.state.reminderCount,
        wasCancelled: true,
      });
    }
    timer?.stop();
    setPhase('idle');
    setTimerState({
      isRunning: false,
      elapsedSeconds: 0,
      reminderCount: 0,
      secondsUntilNextBuzz: 0,
      isComplete: false,
    });
  }, [activeProfile, effectiveInterval, effectiveVariance]);

  // -- done (after completion) ----------------------------------------------
  const handleDone = useCallback(() => {
    setPhase('idle');
    setTimerState({
      isRunning: false,
      elapsedSeconds: 0,
      reminderCount: 0,
      secondsUntilNextBuzz: 0,
      isComplete: false,
    });
    onSessionEnd?.();
  }, [onSessionEnd]);

  // -- progress for finite sessions -----------------------------------------
  const progress = useMemo(() => {
    if (phase !== 'active') return null;

    const totalSec = totalSecondsForCondition(endCondition);
    if (totalSec != null && totalSec > 0) {
      return Math.min(1, timerState.elapsedSeconds / totalSec);
    }

    const totalCount = totalForCondition(endCondition, effectiveInterval);
    if (totalCount != null && totalCount > 0) {
      return Math.min(1, timerState.reminderCount / totalCount);
    }

    return null;
  }, [phase, endCondition, timerState.elapsedSeconds, timerState.reminderCount, effectiveInterval]);

  const progressLabel = useMemo(() => {
    const totalCount = totalForCondition(endCondition, effectiveInterval);
    if (totalCount != null) {
      return `${timerState.reminderCount} of ${totalCount}`;
    }
    return null;
  }, [endCondition, effectiveInterval, timerState.reminderCount]);

  // =========================================================================
  // RENDER
  // =========================================================================

  // -- Completion View ------------------------------------------------------
  if (phase === 'complete') {
    return (
      <View style={styles.container}>
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Checkmark icon */}
          <Text style={styles.completionIcon}>{'\u2705'}</Text>

          <Text style={styles.completionTitle}>Session Complete</Text>

          {/* Stats card */}
          <View style={styles.statsCard}>
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Duration</Text>
              <Text style={styles.statsValue}>{completionStats.duration}</Text>
            </View>
            <View style={styles.statsDivider} />
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Reminders</Text>
              <Text style={styles.statsValue}>{completionStats.reminders}</Text>
            </View>
            <View style={styles.statsDivider} />
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Preset</Text>
              <Text style={styles.statsValue}>{completionStats.presetName}</Text>
            </View>
          </View>

          {/* Done button */}
          <TouchableOpacity
            style={styles.accentButton}
            onPress={handleDone}
            activeOpacity={0.8}
          >
            <Text style={styles.accentButtonText}>Done</Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    );
  }

  // -- Active Session View --------------------------------------------------
  if (phase === 'active') {
    return (
      <View style={styles.container}>
        <View style={styles.activeContent}>
          {/* Big elapsed timer */}
          <Text style={styles.elapsedTimer}>
            {formatTimer(timerState.elapsedSeconds)}
          </Text>

          {/* Reminder count & next buzz */}
          <Text style={styles.activeSubtext}>
            {timerState.reminderCount} reminder{timerState.reminderCount !== 1 ? 's' : ''} {'\u00B7'} next in ~{timerState.secondsUntilNextBuzz}s
          </Text>

          {/* Progress bar (if finite end condition) */}
          {progress != null && (
            <View style={styles.progressContainer}>
              <View style={styles.progressTrack}>
                <View
                  style={[styles.progressFill, { width: `${Math.round(progress * 100)}%` }]}
                />
              </View>
              {progressLabel != null && (
                <Text style={styles.progressLabel}>{progressLabel}</Text>
              )}
            </View>
          )}

          {/* Cancel Session button */}
          <TouchableOpacity
            style={styles.cancelButton}
            onPress={handleCancel}
            activeOpacity={0.8}
          >
            <Text style={styles.cancelButtonText}>Cancel Session</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // -- Idle View ------------------------------------------------------------
  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Large interval display */}
        <Text style={styles.intervalDisplay}>
          {formatTimer(effectiveInterval)}
        </Text>

        {/* Profile name or "Ready to start" */}
        <Text style={activeProfile ? styles.profileNameActive : styles.readyLabel}>
          {activeProfile ? activeProfile.name : 'Ready to start'}
        </Text>

        {/* Preset chips (horizontal scroll) */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chipRow}
          style={styles.chipScroll}
        >
          {presetChips.map((chip) => {
            const isActive = chip.id === selectedProfileId;
            return (
              <TouchableOpacity
                key={chip.id ?? 'quick'}
                style={[
                  styles.chip,
                  isActive ? styles.chipActive : styles.chipInactive,
                ]}
                onPress={() => selectProfile(chip.profile)}
                activeOpacity={0.7}
              >
                <Text
                  style={[
                    styles.chipIcon,
                    isActive ? styles.chipIconActive : styles.chipIconInactive,
                  ]}
                >
                  {chip.icon}
                </Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>

        {/* ---- INTERVAL section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>INTERVAL</Text>
          <View style={styles.pillGrid}>
            {INTERVAL_OPTIONS.map((opt) => {
              const isCustom = opt.seconds === null;
              const isActive = isCustom
                ? isCustomInterval
                : !isCustomInterval && intervalSeconds === opt.seconds;
              return (
                <TouchableOpacity
                  key={opt.label}
                  style={[
                    styles.pill,
                    isActive
                      ? isCustom
                        ? styles.pillAccent
                        : styles.pillActive
                      : styles.pillInactive,
                  ]}
                  onPress={() => {
                    if (isCustom) {
                      setIsCustomInterval(true);
                    } else {
                      setIsCustomInterval(false);
                      setIntervalSeconds(opt.seconds!);
                    }
                  }}
                  activeOpacity={0.7}
                >
                  <Text
                    style={[
                      styles.pillText,
                      isActive ? styles.pillTextActive : styles.pillTextInactive,
                    ]}
                  >
                    {opt.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>

          {/* Custom interval slider (shown when Custom pill is active) */}
          {isCustomInterval && (
            <View style={styles.sliderRow}>
              <Text style={styles.sliderValue}>
                {formatInterval(customInterval)}
              </Text>
              <Slider
                style={styles.slider}
                minimumValue={10}
                maximumValue={600}
                step={5}
                value={customInterval}
                onValueChange={setCustomInterval}
                minimumTrackTintColor={colors.accent}
                maximumTrackTintColor={colors.pillBackground}
                thumbTintColor={colors.accent}
              />
            </View>
          )}
        </View>

        {/* ---- VARY TIMING section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>VARY TIMING</Text>

          <TouchableOpacity
            style={styles.toggleRow}
            onPress={() => setVaryEnabled(!varyEnabled)}
            activeOpacity={0.7}
          >
            <View style={styles.toggleTextCol}>
              <Text style={styles.toggleTitle}>Randomize intervals</Text>
              <Text style={styles.toggleDescription}>
                Each reminder will fire within a random window around the interval
              </Text>
            </View>
            <View
              style={[
                styles.toggleTrack,
                varyEnabled ? styles.toggleTrackOn : styles.toggleTrackOff,
              ]}
            >
              <View
                style={[
                  styles.toggleThumb,
                  varyEnabled ? styles.toggleThumbOn : styles.toggleThumbOff,
                ]}
              />
            </View>
          </TouchableOpacity>

          {varyEnabled && (
            <View style={styles.sliderRow}>
              <Text style={styles.sliderValue}>
                {'\u00B1'}{varianceSeconds}s
              </Text>
              <Slider
                style={styles.slider}
                minimumValue={5}
                maximumValue={60}
                step={5}
                value={varianceSeconds}
                onValueChange={setVarianceSeconds}
                minimumTrackTintColor={colors.accent}
                maximumTrackTintColor={colors.pillBackground}
                thumbTintColor={colors.accent}
              />
            </View>
          )}
        </View>

        {/* ---- END AFTER section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>END AFTER</Text>
          <View style={styles.pillGrid}>
            {END_OPTIONS.map((opt) => {
              const isActive = endConditionsEqual(endCondition, opt.condition);
              return (
                <TouchableOpacity
                  key={opt.label}
                  style={[
                    styles.pill,
                    isActive ? styles.pillActive : styles.pillInactive,
                  ]}
                  onPress={() => setEndCondition(opt.condition)}
                  activeOpacity={0.7}
                >
                  <Text
                    style={[
                      styles.pillText,
                      isActive ? styles.pillTextActive : styles.pillTextInactive,
                    ]}
                  >
                    {opt.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* ---- Start Session button ---- */}
        <TouchableOpacity
          style={styles.startButton}
          onPress={handleStart}
          activeOpacity={0.8}
        >
          <Text style={styles.startButtonText}>Start Session</Text>
        </TouchableOpacity>

        {/* ---- Haptics disclaimer ---- */}
        <Text style={styles.disclaimerText}>
          {'\uD83D\uDCF1'} Haptics and sounds will play on your iPhone
        </Text>
      </ScrollView>
    </View>
  );
}

// ===========================================================================
// Styles
// ===========================================================================

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const styles = StyleSheet.create({
  // -- layout ---------------------------------------------------------------
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: SCREEN_TOP_PAD,
    paddingBottom: 40,
    alignItems: 'center',
  },
  activeContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },

  // -- idle: interval display -----------------------------------------------
  intervalDisplay: {
    fontSize: 56,
    fontWeight: '300',
    fontVariant: ['tabular-nums'],
    color: colors.primary,
    marginBottom: 4,
    ...(Platform.OS === 'ios' ? { fontFamily: 'Menlo' } : { fontFamily: 'monospace' }),
  },
  profileNameActive: {
    fontSize: 13,
    fontWeight: '400',
    color: colors.accent,
    marginBottom: 20,
  },
  readyLabel: {
    fontSize: 13,
    fontWeight: '400',
    color: colors.secondaryText,
    marginBottom: 20,
  },

  // -- preset chips ---------------------------------------------------------
  chipScroll: {
    maxHeight: 56,
    marginBottom: 20,
  },
  chipRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 4,
  },
  chip: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  chipActive: {
    backgroundColor: colors.primary,
  },
  chipInactive: {
    backgroundColor: colors.pillBackground,
  },
  chipIcon: {
    fontSize: 18,
  },
  chipIconActive: {
    color: '#FFFFFF',
  },
  chipIconInactive: {
    color: colors.primary,
  },

  // -- section cards --------------------------------------------------------
  sectionCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    marginBottom: 12,
    width: '100%',
  },
  sectionLabel: {
    fontSize: 9,
    fontWeight: '600',
    letterSpacing: 1.2,
    color: colors.secondaryText,
    textTransform: 'uppercase',
    marginBottom: 10,
  },

  // -- pill grid (3 columns) ------------------------------------------------
  pillGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  pill: {
    width: (SCREEN_WIDTH - 40 - 24 - 16) / 3, // screen - horizontal pad - card pad - gaps
    paddingVertical: 12,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pillActive: {
    backgroundColor: colors.primary,
  },
  pillAccent: {
    backgroundColor: colors.accent,
  },
  pillInactive: {
    backgroundColor: colors.pillBackground,
  },
  pillText: {
    fontSize: 16,
    fontWeight: '500',
  },
  pillTextActive: {
    color: '#FFFFFF',
  },
  pillTextInactive: {
    color: colors.primary,
  },

  // -- slider rows ----------------------------------------------------------
  sliderRow: {
    marginTop: 12,
    width: '100%',
  },
  sliderValue: {
    fontSize: 15,
    fontWeight: '500',
    color: colors.accent,
    textAlign: 'center',
    marginBottom: 4,
  },
  slider: {
    width: '100%',
    height: 36,
  },

  // -- toggle ---------------------------------------------------------------
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  toggleTextCol: {
    flex: 1,
    marginRight: 12,
  },
  toggleTitle: {
    fontSize: 15,
    fontWeight: '500',
    color: colors.primary,
    marginBottom: 2,
  },
  toggleDescription: {
    fontSize: 13,
    color: colors.secondaryText,
    lineHeight: 18,
  },
  toggleTrack: {
    width: 48,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    paddingHorizontal: 2,
  },
  toggleTrackOn: {
    backgroundColor: colors.accent,
  },
  toggleTrackOff: {
    backgroundColor: colors.pillBackground,
  },
  toggleThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
  },
  toggleThumbOn: {
    alignSelf: 'flex-end',
  },
  toggleThumbOff: {
    alignSelf: 'flex-start',
  },

  // -- start button ---------------------------------------------------------
  startButton: {
    backgroundColor: colors.accent,
    paddingVertical: 16,
    borderRadius: 14,
    width: '100%',
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 8,
  },
  startButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },

  // -- disclaimer -----------------------------------------------------------
  disclaimerText: {
    fontSize: 12,
    color: colors.secondaryText,
    marginTop: 4,
    textAlign: 'center',
  },

  // -- active session -------------------------------------------------------
  elapsedTimer: {
    fontSize: 72,
    fontWeight: '300',
    fontVariant: ['tabular-nums'],
    color: colors.accent,
    marginBottom: 8,
    ...(Platform.OS === 'ios' ? { fontFamily: 'Menlo' } : { fontFamily: 'monospace' }),
  },
  activeSubtext: {
    fontSize: 15,
    color: colors.secondaryText,
    marginBottom: 32,
  },

  // -- progress bar ---------------------------------------------------------
  progressContainer: {
    width: '100%',
    paddingHorizontal: 20,
    marginBottom: 32,
    alignItems: 'center',
  },
  progressTrack: {
    width: '100%',
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.pillBackground,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 4,
    backgroundColor: colors.accent,
  },
  progressLabel: {
    fontSize: 13,
    color: colors.secondaryText,
    marginTop: 6,
  },

  // -- cancel button --------------------------------------------------------
  cancelButton: {
    backgroundColor: colors.destructive,
    paddingVertical: 16,
    borderRadius: 14,
    width: '100%',
    alignItems: 'center',
    marginHorizontal: 20,
  },
  cancelButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },

  // -- completion view ------------------------------------------------------
  completionIcon: {
    fontSize: 64,
    marginBottom: 16,
    marginTop: 40,
  },
  completionTitle: {
    fontSize: 28,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 24,
  },
  statsCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 16,
    width: '100%',
    marginBottom: 32,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  statsLabel: {
    fontSize: 15,
    color: colors.secondaryText,
  },
  statsValue: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.primary,
  },
  statsDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.pillBackground,
  },

  // -- accent button (Done) -------------------------------------------------
  accentButton: {
    backgroundColor: colors.accent,
    paddingVertical: 16,
    borderRadius: 14,
    width: '100%',
    alignItems: 'center',
  },
  accentButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
});
