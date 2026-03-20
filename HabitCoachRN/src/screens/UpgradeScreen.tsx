import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { colors, spacing, fontSize } from '../services/theme';
import { PremiumFeature } from '../models/types';

interface Props {
  highlightedFeature?: PremiumFeature;
  onClose: () => void;
  onUnlock: () => void;
}

// ---------- Feature definitions ----------

interface FeatureInfo {
  key: PremiumFeature;
  icon: string;
  title: string;
  subtitle: string;
}

const FEATURES: FeatureInfo[] = [
  {
    key: 'unlimitedPresets',
    icon: '\u2795',
    title: 'Unlimited Presets',
    subtitle: 'Create as many custom presets as you need',
  },
  {
    key: 'allTemplates',
    icon: '\uD83D\uDCCB',
    title: 'All 5 Built-in Templates',
    subtitle: 'Access every pre-configured template',
  },
  {
    key: 'consistentHaptics',
    icon: '\u3030\uFE0F',
    title: 'Consistent Haptic Patterns',
    subtitle: 'Use the same haptic pattern every interval',
  },
  {
    key: 'varyTiming',
    icon: '\u00B1',
    title: 'Vary Timing',
    subtitle: 'Add randomness to interval timing',
  },
  {
    key: 'presetOverrides',
    icon: '\uD83C\uDF9A\uFE0F',
    title: 'Per-Preset Sound & Haptic Overrides',
    subtitle: 'Customize sounds and haptics per preset',
  },
  {
    key: 'morseHaptics',
    icon: '\uD83D\uDCE1',
    title: 'Morse Code Haptics',
    subtitle: 'Receive reminders as Morse code patterns',
  },
  {
    key: 'fullHistory',
    icon: '\uD83D\uDD50',
    title: 'Full Session History',
    subtitle: 'View your complete session log',
  },
  {
    key: 'allThemes',
    icon: '\uD83C\uDFA8',
    title: 'All Themes',
    subtitle: 'Unlock every app theme',
  },
  {
    key: 'sessionBuilder',
    icon: '\uD83D\uDD04',
    title: 'Session Builder',
    subtitle: 'Build multi-step session sequences',
  },
];

// ---------- Feature row ----------

function FeatureRow({
  feature,
  highlighted,
}: {
  feature: FeatureInfo;
  highlighted: boolean;
}) {
  return (
    <View style={[styles.featureRow, highlighted && styles.featureRowHighlighted]}>
      <Text style={styles.featureIcon}>{feature.icon}</Text>
      <View style={styles.featureTextContainer}>
        <Text style={styles.featureTitle}>{feature.title}</Text>
        <Text style={styles.featureSubtitle}>{feature.subtitle}</Text>
      </View>
      {highlighted && <Text style={styles.featureArrow}>{'\u203A'}</Text>}
    </View>
  );
}

// ---------- Main component ----------

export default function UpgradeScreen({ highlightedFeature, onClose, onUnlock }: Props) {
  return (
    <View style={styles.container}>
      {/* Header bar */}
      <View style={styles.headerBar}>
        <Pressable onPress={onClose} style={styles.closeButton}>
          <Text style={styles.closeButtonText}>Close</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        {/* Hero */}
        <View style={styles.hero}>
          <Text style={styles.heroIcon}>{'\u3030\uFE0F'}</Text>
          <Text style={styles.heroTitle}>HabitCoach Premium</Text>
          <Text style={styles.heroSubtitle}>One-time purchase. Unlock everything.</Text>
        </View>

        {/* Feature list card */}
        <View style={styles.featureCard}>
          {FEATURES.map((f) => (
            <FeatureRow
              key={f.key}
              feature={f}
              highlighted={f.key === highlightedFeature}
            />
          ))}
        </View>

        {/* Unlock button */}
        <Pressable style={styles.unlockButton} onPress={onUnlock}>
          <Text style={styles.unlockButtonText}>Unlock for $4.99</Text>
        </Pressable>

        {/* Restore link */}
        <Pressable style={styles.restoreButton}>
          <Text style={styles.restoreButtonText}>Restore Purchase</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

// ---------- Styles ----------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  headerBar: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
  },
  closeButton: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
  },
  closeButtonText: {
    fontSize: fontSize.lg,
    color: colors.accent,
    fontWeight: '600',
  },
  scrollContent: {
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.xxl,
  },
  hero: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  heroIcon: {
    fontSize: 56,
    color: colors.accent,
    marginBottom: spacing.sm,
  },
  heroTitle: {
    fontSize: fontSize.xl,
    fontWeight: 'bold',
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  heroSubtitle: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
  },
  featureCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: spacing.lg,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    paddingHorizontal: spacing.md,
  },
  featureRowHighlighted: {
    backgroundColor: colors.pillBackground,
  },
  featureIcon: {
    fontSize: 18,
    color: colors.accent,
    width: 28,
    textAlign: 'center',
    marginRight: spacing.sm,
  },
  featureTextContainer: {
    flex: 1,
  },
  featureTitle: {
    fontSize: fontSize.md,
    fontWeight: '500',
    color: colors.primary,
  },
  featureSubtitle: {
    fontSize: fontSize.xs,
    color: colors.secondaryText,
    marginTop: 1,
  },
  featureArrow: {
    fontSize: fontSize.xl,
    color: colors.accent,
    marginLeft: spacing.sm,
  },
  unlockButton: {
    backgroundColor: colors.accent,
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  unlockButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.onAccent,
  },
  restoreButton: {
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  restoreButtonText: {
    fontSize: fontSize.md,
    color: colors.accent,
  },
});
