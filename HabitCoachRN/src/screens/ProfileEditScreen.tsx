import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  TextInput,
  Dimensions,
  Platform,
} from 'react-native';
import Slider from '@react-native-community/slider';
import { colors } from '../services/theme';
import { estimatedDuration, defaultMorseWord } from '../services/MorsePlayer';
import { v4 as uuid } from '../models/uuid';
import {
  SessionProfile,
  SessionEndCondition,
  HapticMode,
  HapticPattern,
  HAPTIC_PATTERNS,
  HAPTIC_PATTERN_DISPLAY,
  DEFAULT_SETTINGS,
} from '../models/types';

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
  existing?: SessionProfile;
  isPremium?: boolean;
  onSave: (profile: SessionProfile) => void;
  onClose: () => void;
}

// ---------------------------------------------------------------------------
// Icon grid
// ---------------------------------------------------------------------------

const ICON_OPTIONS: { key: string; emoji: string }[] = [
  { key: 'figure.mixed.cardio', emoji: '\uD83C\uDFCB\uFE0F' },
  { key: 'figure.equestrian.sports', emoji: '\uD83D\uDC34' },
  { key: 'figure.strengthtraining.traditional', emoji: '\uD83D\uDCAA' },
  { key: 'dumbbell.fill', emoji: '\uD83C\uDFCB\uFE0F' },
  { key: 'figure.yoga', emoji: '\uD83E\uDDD8' },
  { key: 'figure.stand', emoji: '\uD83E\uDDCD' },
  { key: 'figure.run', emoji: '\uD83C\uDFC3' },
  { key: 'figure.walk', emoji: '\uD83D\uDEB6' },
  { key: 'figure.cooldown', emoji: '\uD83E\uDDCA' },
  { key: 'figure.pilates', emoji: '\uD83E\uDD38' },
  { key: 'figure.hiking', emoji: '\uD83E\uDD7E' },
  { key: 'figure.dance', emoji: '\uD83D\uDC83' },
  { key: 'figure.martial.arts', emoji: '\uD83E\uDD4B' },
  { key: 'sportscourt.fill', emoji: '\u26BD' },
  { key: 'heart.fill', emoji: '\u2764\uFE0F' },
];

// ---------------------------------------------------------------------------
// Interval presets
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
// Haptic mode display
// ---------------------------------------------------------------------------

const HAPTIC_MODE_OPTIONS: { mode: HapticMode; label: string }[] = [
  { mode: 'randomized', label: 'Randomized' },
  { mode: 'consistent', label: 'Consistent' },
  { mode: 'morse', label: 'Morse Code' },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function endConditionsEqual(a: SessionEndCondition, b: SessionEndCondition): boolean {
  if (a.type !== b.type) return false;
  if (a.type === 'afterCount' && b.type === 'afterCount') return a.count === b.count;
  if (a.type === 'afterDuration' && b.type === 'afterDuration') return a.seconds === b.seconds;
  return true;
}

function formatInterval(seconds: number): string {
  if (seconds >= 60) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return s > 0 ? `${m}m ${s}s` : `${m}m`;
  }
  return `${seconds}s`;
}

function formatCustomMinSec(seconds: number): { min: number; sec: number } {
  return { min: Math.floor(seconds / 60), sec: seconds % 60 };
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function ProfileEditScreen({ existing, isPremium = false, onSave, onClose }: Props) {
  const isEditing = existing != null;

  // -- form state -----------------------------------------------------------
  const [name, setName] = useState(existing?.name ?? '');
  const [icon, setIcon] = useState(existing?.icon ?? ICON_OPTIONS[0].key);

  // Interval
  const presetMatch = INTERVAL_OPTIONS.find(
    (o) => o.seconds != null && o.seconds === existing?.intervalSeconds,
  );
  const [intervalSeconds, setIntervalSeconds] = useState(existing?.intervalSeconds ?? 60);
  const [isCustomInterval, setIsCustomInterval] = useState(!presetMatch && existing != null);
  const [customMinutes, setCustomMinutes] = useState(
    formatCustomMinSec(existing?.intervalSeconds ?? 90).min,
  );
  const [customSecs, setCustomSecs] = useState(
    formatCustomMinSec(existing?.intervalSeconds ?? 90).sec,
  );

  // Vary timing
  const [varyEnabled, setVaryEnabled] = useState((existing?.varianceSeconds ?? 0) > 0);
  const [varianceSeconds, setVarianceSeconds] = useState(existing?.varianceSeconds ?? 15);

  // End condition
  const [endCondition, setEndCondition] = useState<SessionEndCondition>(
    existing?.endCondition ?? { type: 'unlimited' },
  );

  // Haptics
  const [customHapticsEnabled, setCustomHapticsEnabled] = useState(
    existing?.hapticModeOverride != null,
  );
  const [hapticMode, setHapticMode] = useState<HapticMode>(
    existing?.hapticModeOverride ?? DEFAULT_SETTINGS.hapticMode,
  );
  const [hapticPattern, setHapticPattern] = useState<HapticPattern>(
    existing?.hapticPatternOverride ?? DEFAULT_SETTINGS.hapticPattern,
  );
  const [morseWord, setMorseWord] = useState(
    existing?.morseWord ?? defaultMorseWord(existing?.name ?? ''),
  );

  // Sounds
  const [customSoundsEnabled, setCustomSoundsEnabled] = useState(
    existing?.intervalSoundOverride != null,
  );
  const [intervalSound] = useState(existing?.intervalSoundOverride ?? 'none');
  const [completionSound] = useState(existing?.completionSoundOverride ?? 'none');

  // -- derived --------------------------------------------------------------
  const effectiveInterval = isCustomInterval
    ? customMinutes * 60 + customSecs
    : intervalSeconds;

  const canSave = name.trim().length > 0;

  const hapticModeLabel = useMemo(() => {
    const opt = HAPTIC_MODE_OPTIONS.find((o) => o.mode === DEFAULT_SETTINGS.hapticMode);
    return opt?.label ?? 'Randomized';
  }, []);

  const morseDuration = useMemo(() => {
    const word = morseWord.trim() || defaultMorseWord(name);
    return estimatedDuration(word);
  }, [morseWord, name]);

  // -- save handler ---------------------------------------------------------
  const handleSave = () => {
    const profile: SessionProfile = {
      id: existing?.id ?? uuid(),
      name: name.trim(),
      icon,
      intervalSeconds: effectiveInterval,
      varianceSeconds: varyEnabled ? varianceSeconds : 0,
      endCondition,
      notes: existing?.notes ?? '',
      hapticModeOverride: customHapticsEnabled ? hapticMode : undefined,
      hapticPatternOverride:
        customHapticsEnabled && hapticMode === 'consistent' ? hapticPattern : undefined,
      intervalSoundOverride: customSoundsEnabled ? intervalSound : undefined,
      completionSoundOverride: customSoundsEnabled ? completionSound : undefined,
      morseWord:
        customHapticsEnabled && hapticMode === 'morse'
          ? morseWord.trim().toUpperCase() || undefined
          : undefined,
      createdAt: existing?.createdAt ?? new Date().toISOString(),
      isTemplate: existing?.isTemplate ?? false,
      showOnTimer: existing?.showOnTimer ?? true,
    };
    onSave(profile);
  };

  // =========================================================================
  // RENDER
  // =========================================================================

  return (
    <View style={styles.container}>
      {/* ---- Header ---- */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose} activeOpacity={0.7} style={styles.headerButton}>
          <Text style={styles.headerCancel}>Cancel</Text>
        </TouchableOpacity>

        <Text style={styles.headerTitle}>
          {isEditing ? 'Edit Preset' : 'New Preset'}
        </Text>

        <TouchableOpacity
          onPress={canSave ? handleSave : undefined}
          activeOpacity={canSave ? 0.7 : 1}
          style={styles.headerButton}
        >
          <Text style={[styles.headerSave, !canSave && styles.headerSaveDisabled]}>
            Save
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* ---- NAME section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>NAME</Text>
          <TextInput
            style={styles.nameInput}
            value={name}
            onChangeText={setName}
            placeholder="e.g. Morning Stretch, Monday Focus"
            placeholderTextColor={colors.secondaryText}
            autoCapitalize="words"
            returnKeyType="done"
          />
        </View>

        {/* ---- ICON section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>ICON</Text>
          <View style={styles.iconGrid}>
            {ICON_OPTIONS.map((opt) => {
              const isActive = icon === opt.key;
              return (
                <TouchableOpacity
                  key={opt.key}
                  style={[
                    styles.iconButton,
                    isActive ? styles.iconButtonActive : styles.iconButtonInactive,
                  ]}
                  onPress={() => setIcon(opt.key)}
                  activeOpacity={0.7}
                >
                  <Text
                    style={[
                      styles.iconEmoji,
                      isActive ? styles.iconEmojiActive : styles.iconEmojiInactive,
                    ]}
                  >
                    {opt.emoji}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

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

          {isCustomInterval && (
            <View style={styles.customIntervalRow}>
              <View style={styles.customPickerGroup}>
                <TextInput
                  style={styles.customPickerInput}
                  value={String(customMinutes)}
                  onChangeText={(t) => {
                    const n = parseInt(t, 10);
                    if (!isNaN(n) && n >= 0 && n <= 99) setCustomMinutes(n);
                    else if (t === '') setCustomMinutes(0);
                  }}
                  keyboardType="number-pad"
                  maxLength={2}
                />
                <Text style={styles.customPickerLabel}>min</Text>
              </View>
              <Text style={styles.customPickerColon}>:</Text>
              <View style={styles.customPickerGroup}>
                <TextInput
                  style={styles.customPickerInput}
                  value={String(customSecs)}
                  onChangeText={(t) => {
                    const n = parseInt(t, 10);
                    if (!isNaN(n) && n >= 0 && n < 60) setCustomSecs(n);
                    else if (t === '') setCustomSecs(0);
                  }}
                  keyboardType="number-pad"
                  maxLength={2}
                />
                <Text style={styles.customPickerLabel}>sec</Text>
              </View>
            </View>
          )}
        </View>

        {/* ---- VARY TIMING section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>VARY TIMING</Text>
          <TouchableOpacity
            style={styles.toggleRow}
            onPress={() => {
              if (!isPremium) return;
              setVaryEnabled(!varyEnabled);
            }}
            activeOpacity={isPremium ? 0.7 : 1}
          >
            <View style={styles.toggleTextCol}>
              <Text style={styles.toggleTitle}>
                Randomize intervals
                {!isPremium && ' \uD83D\uDD12 Premium'}
              </Text>
              <Text style={styles.toggleDescription}>
                Each reminder will fire within a random window around the interval
              </Text>
            </View>
            {isPremium ? (
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
            ) : (
              <View style={[styles.toggleTrack, styles.toggleTrackOff]}>
                <View style={[styles.toggleThumb, styles.toggleThumbOff]} />
              </View>
            )}
          </TouchableOpacity>

          {varyEnabled && isPremium && (
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

        {/* ---- HAPTICS section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>HAPTICS</Text>
          {!customHapticsEnabled && (
            <Text style={styles.sectionDescription}>
              Using default: {hapticModeLabel}
            </Text>
          )}

          <TouchableOpacity
            style={styles.toggleRow}
            onPress={() => {
              if (!isPremium) return;
              setCustomHapticsEnabled(!customHapticsEnabled);
            }}
            activeOpacity={isPremium ? 0.7 : 1}
          >
            <View style={styles.toggleTextCol}>
              <Text style={styles.toggleTitle}>
                Custom haptics for this preset
                {!isPremium && ' \uD83D\uDD12 Premium'}
              </Text>
            </View>
            {isPremium ? (
              <View
                style={[
                  styles.toggleTrack,
                  customHapticsEnabled ? styles.toggleTrackOn : styles.toggleTrackOff,
                ]}
              >
                <View
                  style={[
                    styles.toggleThumb,
                    customHapticsEnabled ? styles.toggleThumbOn : styles.toggleThumbOff,
                  ]}
                />
              </View>
            ) : (
              <View style={[styles.toggleTrack, styles.toggleTrackOff]}>
                <View style={[styles.toggleThumb, styles.toggleThumbOff]} />
              </View>
            )}
          </TouchableOpacity>

          {customHapticsEnabled && isPremium && (
            <View style={styles.hapticOptions}>
              {/* Haptic mode radio buttons */}
              {HAPTIC_MODE_OPTIONS.map((opt) => {
                const isMorseLocked = opt.mode === 'morse' && !isPremium;
                return (
                  <TouchableOpacity
                    key={opt.mode}
                    style={styles.radioRow}
                    onPress={() => {
                      if (isMorseLocked) return;
                      setHapticMode(opt.mode);
                    }}
                    activeOpacity={isMorseLocked ? 1 : 0.7}
                  >
                    <Text style={[styles.radioLabel, isMorseLocked && { opacity: 0.4 }]}>
                      {opt.label}
                      {isMorseLocked && ' \uD83D\uDD12'}
                    </Text>
                    {hapticMode === opt.mode && (
                      <Text style={styles.radioCheck}>{'\u2713'}</Text>
                    )}
                  </TouchableOpacity>
                );
              })}

              {/* Consistent: pattern sub-list */}
              {hapticMode === 'consistent' && (
                <View style={styles.subList}>
                  {HAPTIC_PATTERNS.map((pat) => (
                    <TouchableOpacity
                      key={pat}
                      style={styles.radioRow}
                      onPress={() => setHapticPattern(pat)}
                      activeOpacity={0.7}
                    >
                      <Text style={styles.subListLabel}>
                        {HAPTIC_PATTERN_DISPLAY[pat]}
                      </Text>
                      {hapticPattern === pat && (
                        <Text style={styles.radioCheck}>{'\u2713'}</Text>
                      )}
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              {/* Morse: word input + duration */}
              {hapticMode === 'morse' && (
                <View style={styles.morseSection}>
                  <Text style={styles.morseLabel}>MORSE WORD</Text>
                  <TextInput
                    style={styles.morseInput}
                    value={morseWord}
                    onChangeText={(t) => {
                      const filtered = t.replace(/[^a-zA-Z]/g, '').toUpperCase();
                      if (filtered.length <= 5) setMorseWord(filtered);
                    }}
                    placeholder={defaultMorseWord(name) || 'WORD'}
                    placeholderTextColor={colors.secondaryText}
                    autoCapitalize="characters"
                    maxLength={5}
                  />
                  <Text style={styles.morseDuration}>
                    Estimated duration: {morseDuration.toFixed(1)}s
                  </Text>
                </View>
              )}
            </View>
          )}
        </View>

        {/* ---- SOUNDS section ---- */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>SOUNDS</Text>
          <TouchableOpacity
            style={styles.toggleRow}
            onPress={() => {
              if (!isPremium) return;
              setCustomSoundsEnabled(!customSoundsEnabled);
            }}
            activeOpacity={isPremium ? 0.7 : 1}
          >
            <View style={styles.toggleTextCol}>
              <Text style={styles.toggleTitle}>
                Custom sounds for this preset
                {!isPremium && ' \uD83D\uDD12 Premium'}
              </Text>
            </View>
            {isPremium ? (
              <View
                style={[
                  styles.toggleTrack,
                  customSoundsEnabled ? styles.toggleTrackOn : styles.toggleTrackOff,
                ]}
              >
                <View
                  style={[
                    styles.toggleThumb,
                    customSoundsEnabled ? styles.toggleThumbOn : styles.toggleThumbOff,
                  ]}
                />
              </View>
            ) : (
              <View style={[styles.toggleTrack, styles.toggleTrackOff]}>
                <View style={[styles.toggleThumb, styles.toggleThumbOff]} />
              </View>
            )}
          </TouchableOpacity>

          {customSoundsEnabled && isPremium && (
            <View style={styles.soundOptions}>
              <View style={styles.soundRow}>
                <Text style={styles.soundLabel}>Interval sound</Text>
                <Text style={styles.soundValue}>None</Text>
              </View>
              <View style={styles.soundRow}>
                <Text style={styles.soundLabel}>Completion sound</Text>
                <Text style={styles.soundValue}>None</Text>
              </View>
            </View>
          )}
        </View>

        {/* ---- DELETE button (editing only) ---- */}
        {isEditing && (
          <TouchableOpacity
            style={styles.deleteButton}
            onPress={onClose}
            activeOpacity={0.7}
          >
            <Text style={styles.deleteButtonText}>Delete Preset</Text>
          </TouchableOpacity>
        )}

        {/* Bottom spacing */}
        <View style={{ height: 40 }} />
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
    paddingBottom: 40,
  },

  // -- header ---------------------------------------------------------------
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: Platform.OS === 'ios' ? 16 : 12,
    paddingBottom: 12,
    backgroundColor: colors.background,
  },
  headerButton: {
    minWidth: 60,
  },
  headerTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: colors.primary,
    textAlign: 'center',
  },
  headerCancel: {
    fontSize: 17,
    color: colors.accent,
  },
  headerSave: {
    fontSize: 17,
    fontWeight: '600',
    color: colors.accent,
    textAlign: 'right',
  },
  headerSaveDisabled: {
    opacity: 0.4,
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
  sectionDescription: {
    fontSize: 13,
    color: colors.secondaryText,
    marginBottom: 10,
  },

  // -- name input -----------------------------------------------------------
  nameInput: {
    backgroundColor: colors.pillBackground,
    borderRadius: 10,
    padding: 10,
    fontSize: 15,
    color: colors.primary,
  },

  // -- icon grid (5 columns) ------------------------------------------------
  iconGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  iconButton: {
    width: (SCREEN_WIDTH - 40 - 24 - 32) / 5, // screen - hPad - cardPad - gaps
    aspectRatio: 1,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconButtonActive: {
    backgroundColor: colors.accent,
  },
  iconButtonInactive: {
    backgroundColor: colors.pillBackground,
  },
  iconEmoji: {
    fontSize: 22,
  },
  iconEmojiActive: {
    // White tint not applicable to emoji; kept for consistency
  },
  iconEmojiInactive: {
    // Primary tint not applicable to emoji; kept for consistency
  },

  // -- pill grid (3 columns) ------------------------------------------------
  pillGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  pill: {
    width: (SCREEN_WIDTH - 40 - 24 - 16) / 3,
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

  // -- custom interval picker -----------------------------------------------
  customIntervalRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 12,
    gap: 8,
  },
  customPickerGroup: {
    alignItems: 'center',
  },
  customPickerInput: {
    backgroundColor: colors.pillBackground,
    borderRadius: 10,
    width: 64,
    height: 44,
    textAlign: 'center',
    fontSize: 20,
    fontWeight: '500',
    color: colors.primary,
    ...(Platform.OS === 'ios' ? { fontFamily: 'Menlo' } : { fontFamily: 'monospace' }),
  },
  customPickerLabel: {
    fontSize: 11,
    color: colors.secondaryText,
    marginTop: 2,
  },
  customPickerColon: {
    fontSize: 20,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 14, // align with input, above label
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

  // -- slider ---------------------------------------------------------------
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

  // -- haptic options -------------------------------------------------------
  hapticOptions: {
    marginTop: 12,
  },
  radioRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.pillBackground,
  },
  radioLabel: {
    fontSize: 15,
    color: colors.primary,
  },
  radioCheck: {
    fontSize: 17,
    fontWeight: '600',
    color: colors.accent,
  },
  subList: {
    paddingLeft: 16,
  },
  subListLabel: {
    fontSize: 14,
    color: colors.primary,
  },

  // -- morse ----------------------------------------------------------------
  morseSection: {
    marginTop: 8,
    paddingLeft: 16,
  },
  morseLabel: {
    fontSize: 9,
    fontWeight: '600',
    letterSpacing: 1.2,
    color: colors.secondaryText,
    textTransform: 'uppercase',
    marginBottom: 6,
  },
  morseInput: {
    backgroundColor: colors.pillBackground,
    borderRadius: 10,
    padding: 10,
    fontSize: 18,
    fontWeight: '600',
    color: colors.primary,
    textAlign: 'center',
    letterSpacing: 4,
    ...(Platform.OS === 'ios' ? { fontFamily: 'Menlo' } : { fontFamily: 'monospace' }),
  },
  morseDuration: {
    fontSize: 13,
    color: colors.secondaryText,
    textAlign: 'center',
    marginTop: 6,
  },

  // -- sound options --------------------------------------------------------
  soundOptions: {
    marginTop: 12,
  },
  soundRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.pillBackground,
  },
  soundLabel: {
    fontSize: 15,
    color: colors.primary,
  },
  soundValue: {
    fontSize: 15,
    color: colors.secondaryText,
  },

  // -- delete button --------------------------------------------------------
  deleteButton: {
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 8,
  },
  deleteButtonText: {
    fontSize: 17,
    color: colors.destructive,
    fontWeight: '500',
  },
});
