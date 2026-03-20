import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, spacing, fontSize, SCREEN_TOP_PAD } from '../services/theme';
import {
  SessionProfile,
  PremiumFeature,
  formatInterval,
  formatEndCondition,
  FREE_TEMPLATE_NAMES,
} from '../models/types';
import { PROFILE_TEMPLATES } from '../models/templates';
import * as Storage from '../services/StorageService';

/** Map SF Symbol names (used in profile.icon) to Ionicons equivalents. */
function mapIcon(sfSymbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    'list.bullet': 'list',
    horse: 'paw',
    dumbbell: 'barbell',
    accessibility: 'accessibility',
    body: 'body',
    fitness: 'fitness',
    timer: 'timer-outline',
    flag: 'flag-outline',
    'arrow.left.arrow.right': 'swap-horizontal',
    'chevron.right': 'chevron-forward',
    'lock.fill': 'lock-closed',
    plus: 'add',
  };
  return (map[sfSymbol] as keyof typeof Ionicons.glyphMap) ?? 'ellipse';
}

const FREE_CUSTOM_PRESET_LIMIT = 2;

interface Props {
  onEditProfile?: (profile: SessionProfile) => void;
  onCreateProfile?: () => void;
  onSelectProfile?: (profile: SessionProfile) => void;
  onShowUpgrade?: (feature: PremiumFeature) => void;
}

export default function ProfileListScreen({
  onEditProfile,
  onCreateProfile,
  onSelectProfile,
  onShowUpgrade,
}: Props) {
  const [profiles, setProfiles] = useState<SessionProfile[]>([]);
  const [isPremium, setIsPremium] = useState(false);

  const loadData = useCallback(async () => {
    const [loaded, premium] = await Promise.all([
      Storage.loadProfiles(),
      Storage.loadPremiumStatus(),
    ]);
    setProfiles(loaded);
    setIsPremium(premium);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Merge user profiles and visible templates, deduplicating by name
  const visibleTemplates = isPremium
    ? PROFILE_TEMPLATES
    : PROFILE_TEMPLATES.filter((t) => FREE_TEMPLATE_NAMES.has(t.name));

  const userProfileNames = new Set(profiles.map((p) => p.name));
  const dedupedTemplates = visibleTemplates.filter((t) => !userProfileNames.has(t.name));
  const allProfiles = [...profiles, ...dedupedTemplates];

  // Count custom (non-template) profiles
  const customProfileCount = profiles.filter((p) => !p.isTemplate).length;
  const atCustomLimit = !isPremium && customProfileCount >= FREE_CUSTOM_PRESET_LIMIT;

  const handleCreate = () => {
    if (atCustomLimit) {
      onShowUpgrade?.('unlimitedPresets');
      return;
    }
    onCreateProfile?.();
  };

  const handleTapProfile = (profile: SessionProfile, locked: boolean) => {
    if (locked) {
      onShowUpgrade?.('allTemplates');
      return;
    }
    // Tap selects for timer, long-press edits
    onSelectProfile?.(profile);
  };

  // ── Empty state ──────────────────────────────────────────────

  const renderEmptyState = () => (
    <View style={styles.emptyContainer}>
      <Ionicons name="list" size={36} color={colors.secondaryText} />
      <Text style={styles.emptyTitle}>No Presets Yet</Text>
      <Text style={styles.emptyDescription}>
        {'Save configurations for workouts, habits,\nroutines, or anything on a schedule.'}
      </Text>
      <TouchableOpacity
        style={styles.capsuleButton}
        onPress={handleCreate}
        activeOpacity={0.8}
      >
        <Text style={styles.capsuleButtonText}>Create Preset</Text>
      </TouchableOpacity>
    </View>
  );

  // ── Profile card ─────────────────────────────────────────────

  const renderProfileCard = (profile: SessionProfile) => {
    const isLocked =
      profile.isTemplate &&
      !FREE_TEMPLATE_NAMES.has(profile.name) &&
      !isPremium;

    return (
      <TouchableOpacity
        key={profile.id}
        style={styles.card}
        onPress={() => handleTapProfile(profile, isLocked)}
        onLongPress={() => {
          if (!profile.isTemplate) onEditProfile?.(profile);
        }}
        activeOpacity={0.7}
        accessibilityLabel={`${profile.name} preset, ${formatInterval(profile.intervalSeconds)} interval${isLocked ? ', locked' : ''}`}
        accessibilityHint={isLocked ? 'Tap to unlock with Premium' : 'Tap to edit'}
      >
        {/* Icon circle */}
        <View style={styles.iconCircle}>
          <Ionicons
            name={mapIcon(profile.icon)}
            size={24}
            color={colors.accent}
          />
        </View>

        {/* Name + stats */}
        <View style={styles.cardCenter}>
          <Text style={styles.cardName}>{profile.name}</Text>
          <View style={styles.statsRow}>
            <View style={styles.statItem}>
              <Ionicons
                name="timer-outline"
                size={12}
                color={colors.secondaryText}
              />
              <Text style={styles.statText}>
                {formatInterval(profile.intervalSeconds)}
              </Text>
            </View>
            {profile.varianceSeconds > 0 && (
              <View style={styles.statItem}>
                <Ionicons
                  name="swap-horizontal"
                  size={12}
                  color={colors.secondaryText}
                />
                <Text style={styles.statText}>
                  {'\u00B1 '}
                  {profile.varianceSeconds}s
                </Text>
              </View>
            )}
            <View style={styles.statItem}>
              <Ionicons
                name="flag-outline"
                size={12}
                color={colors.secondaryText}
              />
              <Text style={styles.statText}>
                {formatEndCondition(profile.endCondition)}
              </Text>
            </View>
          </View>
        </View>

        {/* Trailing icon */}
        {isLocked ? (
          <Ionicons
            name="lock-closed"
            size={14}
            color={colors.secondaryText}
          />
        ) : (
          <Ionicons
            name="chevron-forward"
            size={14}
            color={colors.secondaryText}
          />
        )}
      </TouchableOpacity>
    );
  };

  // ── Main render ──────────────────────────────────────────────

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Presets</Text>
        {atCustomLimit ? (
          <TouchableOpacity
            style={[styles.addButton, { backgroundColor: colors.secondaryText }]}
            onPress={() => onShowUpgrade?.('unlimitedPresets')}
            activeOpacity={0.8}
            accessibilityLabel="Unlock unlimited presets with Premium"
          >
            <Ionicons name="lock-closed" size={14} color={colors.onAccent} />
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={styles.addButton}
            onPress={handleCreate}
            activeOpacity={0.8}
            accessibilityLabel="Create new preset"
          >
            <Ionicons name="add" size={16} color={colors.onAccent} />
          </TouchableOpacity>
        )}
      </View>

      {/* Content */}
      {allProfiles.length === 0 ? (
        renderEmptyState()
      ) : (
        <ScrollView contentContainerStyle={styles.list}>
          {allProfiles.map(renderProfileCard)}
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },

  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: SCREEN_TOP_PAD,
    paddingBottom: 12,
  },
  title: {
    fontSize: fontSize.xl,
    fontWeight: '700',
    color: colors.primary,
  },
  addButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },

  // Empty state
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
  },
  emptyTitle: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginTop: spacing.sm,
  },
  emptyDescription: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  capsuleButton: {
    backgroundColor: colors.accent,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 20,
    marginTop: 16,
  },
  capsuleButtonText: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.onAccent,
  },

  // List
  list: {
    paddingHorizontal: 16,
    paddingBottom: spacing.lg,
  },

  // Card
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.pillBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  cardCenter: {
    flex: 1,
  },
  cardName: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 6,
  },
  statsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
  },
  statItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  statText: {
    fontSize: fontSize.xs,
    color: colors.secondaryText,
  },
});
