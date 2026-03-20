import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
} from 'react-native';
import { colors, spacing, fontSize, SCREEN_TOP_PAD } from '../services/theme';
import { Session, formatDuration, formatInterval } from '../models/types';
import { useAppContext } from '../services/AppContext';
import * as Storage from '../services/StorageService';

const FREE_HISTORY_LIMIT = 5;

// ---------- Helpers ----------

function formatSessionDate(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  }) + ', ' + date.toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });
}

// ---------- Main screen ----------

export default function HistoryScreen() {
  const { isPremium, unlockPremium } = useAppContext();
  const [sessions, setSessions] = useState<Session[]>([]);

  const loadData = useCallback(() => {
    Storage.loadSessions().then(setSessions);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  /** Expose for parent to call after a session ends */
  const refresh = loadData;

  const handleClearAll = () => {
    Alert.alert(
      'Clear All History?',
      `This will permanently delete all ${sessions.length} sessions.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear All',
          style: 'destructive',
          onPress: async () => {
            await Storage.saveSessions([]);
            setSessions([]);
          },
        },
      ],
    );
  };

  // ---------- Render helpers ----------

  const renderSession = ({ item }: { item: Session }) => {
    const dateStr = formatSessionDate(item.startedAt);
    const duration =
      item.endedAt ? formatDuration(item.startedAt, item.endedAt) : '--';
    const interval = formatInterval(item.intervalSeconds);

    return (
      <View
        style={styles.sessionCard}
        accessible
        accessibilityLabel={`${item.profileName}, ${duration}, ${item.reminderCount} reminders${item.wasCancelled ? ', cancelled' : ''}`}
      >
        {/* Top row: date + cancelled badge */}
        <View style={styles.topRow}>
          <Text style={styles.dateText}>{dateStr}</Text>
          {item.wasCancelled && (
            <Text style={styles.cancelledBadge}>Cancelled</Text>
          )}
        </View>

        {/* Profile name */}
        <Text style={styles.profileName}>{item.profileName}</Text>

        {/* Stats row */}
        <View style={styles.statsRow}>
          <View style={styles.statItem}>
            <Text style={styles.statIcon}>{'⏱'}</Text>
            <Text style={styles.statText}>{duration}</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statIcon}>{'🔔'}</Text>
            <Text style={styles.statText}>{item.reminderCount} buzzes</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statIcon}>{'🔁'}</Text>
            <Text style={styles.statText}>{interval}</Text>
          </View>
        </View>
      </View>
    );
  };

  const emptyState = (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyIcon}>{'🕐'}</Text>
      <Text style={styles.emptyHeadline}>No Sessions Yet</Text>
      <Text style={styles.emptySubtext}>
        Your completed sessions will appear here.
      </Text>
    </View>
  );

  // ---------- Layout ----------

  const headerTitle =
    sessions.length > 0 ? `History (${sessions.length})` : 'History';

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.screenTitle}>{headerTitle}</Text>
        {sessions.length > 0 && (
          <Pressable
            onPress={handleClearAll}
            accessibilityRole="button"
            accessibilityLabel="Clear all sessions"
          >
            <Text style={styles.clearAllText}>Clear All</Text>
          </Pressable>
        )}
      </View>

      {sessions.length === 0 ? (
        emptyState
      ) : (
        <FlatList
          data={isPremium ? sessions : sessions.slice(0, FREE_HISTORY_LIMIT)}
          keyExtractor={(item) => item.id}
          renderItem={renderSession}
          contentContainerStyle={styles.list}
          ListFooterComponent={
            !isPremium && sessions.length > FREE_HISTORY_LIMIT ? (
              <Pressable
                style={styles.upgradePrompt}
                onPress={unlockPremium}
                accessibilityRole="button"
                accessibilityLabel="View full history with Premium"
              >
                <Text style={styles.upgradePromptText}>
                  View full history ({sessions.length} sessions) {'\u2014'} Premium
                </Text>
              </Pressable>
            ) : null
          }
        />
      )}
    </View>
  );
}

// ---------- Styles ----------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },

  // Header
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: SCREEN_TOP_PAD,
    paddingBottom: 12,
  },
  screenTitle: {
    fontSize: fontSize.xl, // title2 bold
    fontWeight: '700',
    color: colors.primary,
  },
  clearAllText: {
    fontSize: 12,
    fontWeight: '500',
    color: colors.destructive,
  },

  // List
  list: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },

  // Session card
  sessionCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dateText: {
    fontSize: fontSize.sm,
    fontWeight: '500',
    color: colors.primary,
  },
  cancelledBadge: {
    fontSize: 12,
    fontWeight: '500',
    color: colors.destructive,
  },
  profileName: {
    fontSize: 12,
    fontWeight: '500',
    color: colors.accent,
    marginTop: 4,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 16,
    marginTop: 6,
  },
  statItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  statIcon: {
    fontSize: 12,
  },
  statText: {
    fontSize: 12,
    color: colors.secondaryText,
  },

  // Empty state
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  emptyIcon: {
    fontSize: 36,
    marginBottom: 8,
  },
  emptyHeadline: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 4,
  },
  emptySubtext: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
    textAlign: 'center',
  },

  // Upgrade prompt
  upgradePrompt: {
    paddingVertical: 14,
    paddingHorizontal: 16,
    alignItems: 'center',
    marginTop: 4,
  },
  upgradePromptText: {
    fontSize: fontSize.sm,
    fontWeight: '600',
    color: colors.accent,
  },
});
