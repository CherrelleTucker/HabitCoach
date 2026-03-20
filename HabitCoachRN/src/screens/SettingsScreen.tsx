import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Switch,
} from 'react-native';
import { colors, spacing, fontSize, SCREEN_TOP_PAD, THEMES, THEME_KEYS, setTheme, getThemeKey } from '../services/theme';
import type { AppTheme } from '../services/theme';
import {
  SessionSettings,
  DEFAULT_SETTINGS,
  HapticMode,
  HapticPattern,
  PremiumFeature,
  HAPTIC_PATTERNS,
  HAPTIC_PATTERN_DISPLAY,
} from '../models/types';
import { playHaptic } from '../services/HapticService';
import * as Storage from '../services/StorageService';
import { useAppContext } from '../services/AppContext';

// ---------- FAQ data (adapted from SettingsView.swift, no Apple Watch refs) ----------

const FAQ_ITEMS: { q: string; a: string }[] = [
  {
    q: 'Why are haptics randomized by default?',
    a: 'Your body naturally adapts to repeated stimuli and tunes them out. Varying the haptic pattern each buzz keeps you noticing the reminder.',
  },
  {
    q: 'What does Focus mode do?',
    a: "It silences other app notifications during your session. On Android, enable Do Not Disturb before starting a session for an uninterrupted experience.",
  },
  {
    q: 'How do preset overrides work?',
    a: "Each preset starts with your global default settings above. When editing a preset, toggle 'Custom' to change sounds or haptics for that specific activity.",
  },
  {
    q: 'Will the screen stay on?',
    a: 'Yes. Your device prevents sleep during active sessions so you never lose your timer.',
  },
  {
    q: 'How is session history stored?',
    a: 'Sessions are stored locally on your device.',
  },
];

// ---------- Sub-components ----------

function SectionLabel({ text }: { text: string }) {
  return <Text style={styles.sectionLabel}>{text}</Text>;
}

function SectionCard({ children }: { children: React.ReactNode }) {
  return <View style={styles.sectionCard}>{children}</View>;
}

function Checkmark() {
  return <Text style={styles.checkmark}>{'✓'}</Text>;
}

function ChevronRight() {
  return <Text style={styles.chevron}>{'›'}</Text>;
}

function FAQItem({ q, a }: { q: string; a: string }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <View>
      <Pressable
        style={styles.faqRow}
        onPress={() => setExpanded(!expanded)}
        accessibilityRole="button"
        accessibilityLabel={q}
      >
        <Text style={styles.rowText}>{q}</Text>
        <Text style={[styles.disclosureArrow, expanded && styles.disclosureArrowOpen]}>
          {'›'}
        </Text>
      </Pressable>
      {expanded && <Text style={styles.faqAnswer}>{a}</Text>}
    </View>
  );
}

// ---------- Main screen ----------

interface Props {
  onShowPrivacyPolicy?: () => void;
  onShowUpgrade?: (feature: PremiumFeature) => void;
}

export default function SettingsScreen({ onShowPrivacyPolicy, onShowUpgrade }: Props = {}) {
  const { isPremium } = useAppContext();
  const [settings, setSettings] = useState<SessionSettings>(DEFAULT_SETTINGS);
  const [soundsExpanded, setSoundsExpanded] = useState(false);
  const [, forceRender] = useState(0);

  useEffect(() => {
    Storage.loadSettings().then(setSettings);
  }, []);

  const update = (partial: Partial<SessionSettings>) => {
    const next = { ...settings, ...partial };
    setSettings(next);
    Storage.saveSettings(next);
  };

  // ---------- Haptic mode helpers ----------

  const hapticModeRows: {
    value: HapticMode;
    label: string;
    subtitle: string;
  }[] = [
    {
      value: 'randomized',
      label: 'Randomized',
      subtitle: "Varies each buzz so you don't tune it out",
    },
    {
      value: 'consistent',
      label: 'Consistent',
      subtitle: 'Same pattern every time',
    },
    {
      value: 'morse',
      label: 'Morse Code',
      subtitle: 'Spells a word in taps you can feel',
    },
  ];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Title */}
      <Text style={styles.screenTitle}>Settings</Text>

      <View style={styles.sectionGap}>
        {/* ── DEFAULT HAPTICS ── */}
        <SectionCard>
          <SectionLabel text="DEFAULT HAPTICS" />

          {hapticModeRows.map((mode, index) => {
            const isLockedMode =
              !isPremium &&
              (mode.value === 'consistent' || mode.value === 'morse');
            const premiumFeature: PremiumFeature =
              mode.value === 'morse' ? 'morseHaptics' : 'consistentHaptics';

            return (
            <React.Fragment key={mode.value}>
              <Pressable
                style={styles.row}
                onPress={() => {
                  if (isLockedMode) {
                    onShowUpgrade?.(premiumFeature);
                    return;
                  }
                  update({ hapticMode: mode.value });
                }}
                accessibilityRole="radio"
                accessibilityState={{ selected: settings.hapticMode === mode.value }}
              >
                <View style={styles.rowTextGroup}>
                  <Text style={[styles.rowText, isLockedMode && styles.lockedText]}>
                    {mode.label}
                    {isLockedMode && ' \uD83D\uDD12'}
                  </Text>
                  <Text style={styles.rowSubtext}>{mode.subtitle}</Text>
                </View>
                {settings.hapticMode === mode.value && !isLockedMode && <Checkmark />}
              </Pressable>

              {/* Pattern sub-list when Consistent is selected */}
              {mode.value === 'consistent' && settings.hapticMode === 'consistent' && (
                <>
                  <View style={styles.divider} />
                  {HAPTIC_PATTERNS.map((pattern: HapticPattern) => (
                    <Pressable
                      key={pattern}
                      style={styles.row}
                      onPress={() => {
                        update({ hapticPattern: pattern });
                        playHaptic(pattern);
                      }}
                      accessibilityRole="radio"
                      accessibilityState={{ selected: settings.hapticPattern === pattern }}
                    >
                      <Text style={styles.rowText}>{HAPTIC_PATTERN_DISPLAY[pattern]}</Text>
                      {settings.hapticPattern === pattern && <Checkmark />}
                    </Pressable>
                  ))}
                </>
              )}

              {/* Show Morse after Consistent patterns (if consistent selected, Morse comes after patterns) */}
            </React.Fragment>
          );
          })}
        </SectionCard>

        {/* ── DEFAULT SOUNDS ── */}
        <SectionCard>
          <Pressable
            style={styles.row}
            onPress={() => setSoundsExpanded(!soundsExpanded)}
            accessibilityRole="button"
          >
            <SectionLabel text="DEFAULT SOUNDS" />
            <Text style={[styles.disclosureArrow, soundsExpanded && styles.disclosureArrowOpen]}>
              {'›'}
            </Text>
          </Pressable>

          {soundsExpanded && (
            <View style={styles.soundsBody}>
              <Text style={styles.faqAnswer}>
                Presets inherit these unless customized.
              </Text>

              {/* Interval sound */}
              <Text style={styles.soundSectionLabel}>Interval</Text>
              <Pressable style={styles.row}>
                <Text style={styles.rowText}>None</Text>
                {settings.intervalSound === 'none' && <Checkmark />}
              </Pressable>

              <View style={styles.divider} />

              {/* Completion sound */}
              <Text style={styles.soundSectionLabel}>Session Complete</Text>
              <Pressable style={styles.row}>
                <Text style={styles.rowText}>None</Text>
                {settings.completionSound === 'none' && <Checkmark />}
              </Pressable>
            </View>
          )}
        </SectionCard>

        {/* ── FOCUS REMINDER ── */}
        <SectionCard>
          <View style={styles.focusHeader}>
            <View style={{ flex: 1 }}>
              <SectionLabel text="FOCUS REMINDER" />
              <Text style={styles.focusCaption}>
                Show tip to enable Focus before sessions
              </Text>
            </View>
            <Switch
              value={settings.focusReminderEnabled}
              onValueChange={(val) => update({ focusReminderEnabled: val })}
              trackColor={{ false: colors.pillBackground, true: colors.accent }}
              thumbColor={colors.onAccent}
              accessibilityLabel="Focus reminder toggle"
            />
          </View>

          <Text style={styles.faqAnswer}>
            When enabled, a tip appears on the timer screen reminding you to
            enable Do Not Disturb for an uninterrupted session.
          </Text>
          <Text style={styles.faqAnswer}>
            Haptics will play during active sessions.
          </Text>
        </SectionCard>

        {/* ── THEMES ── */}
        <SectionCard>
          <SectionLabel text="THEMES" />
          {THEME_KEYS.map((key: AppTheme) => {
            const entry = THEMES[key];
            const isSelected = (settings.theme ?? 'coachAuthority') === key;
            const isLocked = key !== 'coachAuthority' && !isPremium;
            return (
              <Pressable
                key={key}
                style={styles.row}
                onPress={() => {
                  if (isLocked) return;
                  setTheme(key);
                  const next = { ...settings, theme: key };
                  setSettings(next);
                  Storage.saveSettings(next);
                  forceRender((n) => n + 1);
                }}
                accessibilityRole="radio"
                accessibilityState={{ selected: isSelected }}
              >
                <View style={styles.themeRowLeft}>
                  <View
                    style={[
                      styles.themeSwatch,
                      { backgroundColor: entry.colors.primary },
                    ]}
                  >
                    <View
                      style={[
                        styles.themeSwatchAccent,
                        { backgroundColor: entry.colors.accent },
                      ]}
                    />
                  </View>
                  <Text
                    style={[
                      styles.rowText,
                      isLocked && styles.lockedText,
                    ]}
                  >
                    {entry.displayName}
                  </Text>
                </View>
                {isLocked ? (
                  <Text style={styles.lockIcon}>{'🔒'}</Text>
                ) : isSelected ? (
                  <Checkmark />
                ) : null}
              </Pressable>
            );
          })}
        </SectionCard>

        {/* ── FAQ ── */}
        <SectionCard>
          <SectionLabel text="FAQ" />
          {FAQ_ITEMS.map((item) => (
            <FAQItem key={item.q} q={item.q} a={item.a} />
          ))}
        </SectionCard>

        {/* ── PRIVACY POLICY ── */}
        <SectionCard>
          <Pressable
            style={styles.row}
            onPress={() => onShowPrivacyPolicy?.()}
            accessibilityRole="button"
            accessibilityLabel="Privacy Policy"
          >
            <Text style={styles.rowText}>Privacy Policy</Text>
            <ChevronRight />
          </Pressable>
        </SectionCard>

        {/* ── VERSION ── */}
        <SectionCard>
          <View style={styles.row}>
            <Text style={styles.rowText}>Version</Text>
            <Text style={styles.versionText}>1.0.0</Text>
          </View>
        </SectionCard>
      </View>
    </ScrollView>
  );
}

// ---------- Styles ----------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },
  screenTitle: {
    fontSize: fontSize.xl,
    fontWeight: '700',
    color: colors.primary,
    paddingTop: SCREEN_TOP_PAD,
    paddingBottom: 12,
  },
  sectionGap: {
    gap: 6,
  },

  // Section card
  sectionCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 10,
  },

  // Section label (9pt uppercase tracking)
  sectionLabel: {
    fontSize: fontSize.xs, // 9
    fontWeight: '500',
    color: colors.secondaryText,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },

  // Generic row
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  rowTextGroup: {
    flex: 1,
    gap: 2,
  },
  rowText: {
    fontSize: fontSize.sm, // ~subheadline
    color: colors.primary,
  },
  rowSubtext: {
    fontSize: 10,
    color: colors.secondaryText,
  },

  // Checkmark
  checkmark: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.accent,
  },

  // Chevron
  chevron: {
    fontSize: 18,
    color: colors.secondaryText,
    fontWeight: '400',
  },

  // Divider
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.pillBackground,
    marginVertical: 4,
  },

  // Disclosure arrow
  disclosureArrow: {
    fontSize: 18,
    color: colors.accent,
    fontWeight: '600',
    transform: [{ rotate: '0deg' }],
  },
  disclosureArrowOpen: {
    transform: [{ rotate: '90deg' }],
  },

  // Sounds
  soundsBody: {
    paddingTop: 4,
  },
  soundSectionLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: colors.primary,
    marginTop: 8,
    marginBottom: 4,
  },

  // Focus
  focusHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  focusCaption: {
    fontSize: 12,
    color: colors.secondaryText,
    marginTop: 2,
  },

  // FAQ
  faqRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
  faqAnswer: {
    fontSize: 10,
    color: colors.secondaryText,
    paddingTop: 2,
    paddingBottom: 4,
  },

  // Theme
  themeRowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  themeSwatch: {
    width: 22,
    height: 22,
    borderRadius: 6,
    alignItems: 'flex-end',
    justifyContent: 'flex-end',
  },
  themeSwatchAccent: {
    width: 10,
    height: 10,
    borderRadius: 3,
    margin: 2,
  },
  lockedText: {
    opacity: 0.45,
  },
  lockIcon: {
    fontSize: 14,
  },

  // Version
  versionText: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
  },
});
