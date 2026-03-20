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
  SessionSequence,
  PremiumFeature,
} from '../models/types';
import * as Storage from '../services/StorageService';

/** Map SF Symbol names to Ionicons equivalents. */
function mapIcon(sfSymbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    'arrow.triangle.2.circlepath': 'repeat',
    'list.number': 'list',
    timer: 'timer-outline',
    'arrow.right': 'arrow-forward',
    'play.fill': 'play',
    'lock.fill': 'lock-closed',
    plus: 'add',
  };
  return (map[sfSymbol] as keyof typeof Ionicons.glyphMap) ?? 'ellipse';
}

/** Estimate total duration of a sequence from its steps. */
function estimateTotalDuration(sequence: SessionSequence): number | null {
  let total = 0;
  for (const step of sequence.steps) {
    const end = step.endCondition;
    if (end.type === 'afterDuration') {
      total += end.seconds;
    } else if (end.type === 'afterCount') {
      total += end.count * step.profile.intervalSeconds;
    } else {
      // unlimited — can't estimate
      return null;
    }
  }
  return total;
}

function formatTotalDuration(seconds: number): string {
  if (seconds >= 3600) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return m > 0 ? `${h}h ${m}m` : `${h}h`;
  }
  const m = Math.floor(seconds / 60);
  return `${m}m`;
}

interface Props {
  onEditSequence?: (sequence: SessionSequence) => void;
  onCreateSequence?: () => void;
  onPlaySequence?: (sequence: SessionSequence) => void;
  onShowUpgrade?: (feature: PremiumFeature) => void;
}

export default function SequenceListScreen({
  onEditSequence,
  onCreateSequence,
  onPlaySequence,
  onShowUpgrade,
}: Props) {
  const [sequences, setSequences] = useState<SessionSequence[]>([]);
  const [isPremium, setIsPremium] = useState(false);

  const loadData = useCallback(async () => {
    const [loaded, premium] = await Promise.all([
      Storage.loadSequences(),
      Storage.loadPremiumStatus(),
    ]);
    setSequences(loaded);
    setIsPremium(premium);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // ── Non-premium prompt ───────────────────────────────────────

  const renderPremiumPrompt = () => (
    <View style={styles.centeredContainer}>
      <Ionicons name="repeat" size={36} color={colors.secondaryText} />
      <Text style={styles.centeredTitle}>Session Builder</Text>
      <Text style={styles.centeredDescription}>
        {'Chain presets into a sequence.\nOne tap starts the whole flow.'}
      </Text>
      <TouchableOpacity
        style={styles.capsuleButton}
        onPress={() => onShowUpgrade?.('sessionBuilder')}
        activeOpacity={0.8}
      >
        <View style={styles.capsuleInner}>
          <Ionicons name="lock-closed" size={12} color={colors.onAccent} />
          <Text style={styles.capsuleButtonText}>Unlock with Premium</Text>
        </View>
      </TouchableOpacity>
    </View>
  );

  // ── Empty state (premium) ────────────────────────────────────

  const renderEmptyState = () => (
    <View style={styles.centeredContainer}>
      <Ionicons name="repeat" size={36} color={colors.secondaryText} />
      <Text style={styles.centeredTitle}>No Sequences Yet</Text>
      <Text style={styles.centeredDescription}>
        {'Chain presets into a full workout.\nWarm up, train, cool down \u2014 one tap.'}
      </Text>
      <TouchableOpacity
        style={styles.capsuleButton}
        onPress={() => onCreateSequence?.()}
        activeOpacity={0.8}
      >
        <Text style={styles.capsuleButtonText}>Create Sequence</Text>
      </TouchableOpacity>
    </View>
  );

  // ── Sequence card ────────────────────────────────────────────

  const renderSequenceCard = (sequence: SessionSequence) => {
    const totalDuration = estimateTotalDuration(sequence);

    return (
      <TouchableOpacity
        key={sequence.id}
        style={styles.card}
        onPress={() => onPlaySequence?.(sequence)}
        onLongPress={() => onEditSequence?.(sequence)}
        activeOpacity={0.7}
        accessibilityLabel={`${sequence.name} sequence, ${sequence.steps.length} steps`}
      >
        {/* Icon circle */}
        <View style={styles.iconCircle}>
          <Ionicons
            name={mapIcon(sequence.icon)}
            size={24}
            color={colors.accent}
          />
        </View>

        {/* Name + stats */}
        <View style={styles.cardCenter}>
          <Text style={styles.cardName}>{sequence.name}</Text>
          <View style={styles.statsRow}>
            <View style={styles.statItem}>
              <Ionicons name="list" size={12} color={colors.secondaryText} />
              <Text style={styles.statText}>
                {sequence.steps.length} steps
              </Text>
            </View>
            {totalDuration !== null && (
              <View style={styles.statItem}>
                <Ionicons
                  name="timer-outline"
                  size={12}
                  color={colors.secondaryText}
                />
                <Text style={styles.statText}>
                  {formatTotalDuration(totalDuration)}
                </Text>
              </View>
            )}
            <View style={styles.statItem}>
              <Ionicons
                name="arrow-forward"
                size={12}
                color={colors.secondaryText}
              />
              <Text style={styles.statText}>
                {sequence.transition === 'autoAdvance' ? 'Auto' : 'Manual'}
              </Text>
            </View>
          </View>
        </View>

        {/* Play icon */}
        <Ionicons name="play" size={14} color={colors.accent} />
      </TouchableOpacity>
    );
  };

  // ── Main render ──────────────────────────────────────────────

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Sequences</Text>
        {isPremium && (
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => onCreateSequence?.()}
            activeOpacity={0.8}
            accessibilityLabel="Create new sequence"
          >
            <Ionicons name="add" size={16} color={colors.onAccent} />
          </TouchableOpacity>
        )}
      </View>

      {/* Content */}
      {!isPremium ? (
        renderPremiumPrompt()
      ) : sequences.length === 0 ? (
        renderEmptyState()
      ) : (
        <ScrollView contentContainerStyle={styles.list}>
          {sequences.map(renderSequenceCard)}
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

  // Centered states (empty + premium prompt)
  centeredContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
  },
  centeredTitle: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginTop: spacing.sm,
  },
  centeredDescription: {
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
    marginTop: 12,
  },
  capsuleInner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
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
