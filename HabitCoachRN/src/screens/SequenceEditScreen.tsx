import React, { useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Modal,
  Platform,
  Dimensions,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, spacing, fontSize } from '../services/theme';
import {
  SessionProfile,
  SessionSequence,
  SequenceStep,
  SequenceTransition,
  SessionEndCondition,
  formatInterval,
  formatEndCondition,
} from '../models/types';
import { v4 as uuid } from '../models/uuid';

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
  existing?: SessionSequence;
  onSave: (seq: SessionSequence) => void;
  onClose: () => void;
  profiles: SessionProfile[];
}

// ---------------------------------------------------------------------------
// End-condition options for step configuration
// ---------------------------------------------------------------------------

interface EndOption {
  label: string;
  condition: SessionEndCondition;
}

const END_OPTIONS: EndOption[] = [
  { label: '5\u00D7', condition: { type: 'afterCount', count: 5 } },
  { label: '10\u00D7', condition: { type: 'afterCount', count: 10 } },
  { label: '15\u00D7', condition: { type: 'afterCount', count: 15 } },
  { label: '5 min', condition: { type: 'afterDuration', seconds: 300 } },
  { label: '10 min', condition: { type: 'afterDuration', seconds: 600 } },
  { label: '15 min', condition: { type: 'afterDuration', seconds: 900 } },
  { label: '30 min', condition: { type: 'afterDuration', seconds: 1800 } },
];

// ---------------------------------------------------------------------------
// Countdown options
// ---------------------------------------------------------------------------

const COUNTDOWN_OPTIONS = [3, 5, 10];

// ---------------------------------------------------------------------------
// Icon mapping (mirrors ProfileListScreen)
// ---------------------------------------------------------------------------

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
    plus: 'add',
  };
  return (map[sfSymbol] as keyof typeof Ionicons.glyphMap) ?? 'ellipse';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function endConditionsEqual(a: SessionEndCondition, b: SessionEndCondition): boolean {
  if (a.type !== b.type) return false;
  if (a.type === 'afterCount' && b.type === 'afterCount') return a.count === b.count;
  if (a.type === 'afterDuration' && b.type === 'afterDuration') return a.seconds === b.seconds;
  return true;
}

function isStepValid(step: SequenceStep): boolean {
  return step.endCondition.type !== 'unlimited';
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function SequenceEditScreen({
  existing,
  onSave,
  onClose,
  profiles,
}: Props) {
  const isEditing = existing != null;

  // -- form state -----------------------------------------------------------
  const [name, setName] = useState(existing?.name ?? '');
  const [steps, setSteps] = useState<SequenceStep[]>(existing?.steps ?? []);
  const [transition, setTransition] = useState<SequenceTransition>(
    existing?.transition ?? 'autoAdvance',
  );
  const [countdownSeconds, setCountdownSeconds] = useState(
    existing?.countdownSeconds ?? 5,
  );

  // -- add-step picker state ------------------------------------------------
  const [showProfilePicker, setShowProfilePicker] = useState(false);
  const [pendingProfile, setPendingProfile] = useState<SessionProfile | null>(null);
  const [pendingEndCondition, setPendingEndCondition] = useState<SessionEndCondition>(
    END_OPTIONS[0].condition,
  );

  // -- validation -----------------------------------------------------------
  const isValid = useMemo(() => {
    if (name.trim().length === 0) return false;
    if (steps.length === 0) return false;
    return steps.every(isStepValid);
  }, [name, steps]);

  // -- step manipulation ----------------------------------------------------
  const removeStep = useCallback((id: string) => {
    setSteps((prev) => prev.filter((s) => s.id !== id));
  }, []);

  const moveStep = useCallback((index: number, direction: 'up' | 'down') => {
    setSteps((prev) => {
      const next = [...prev];
      const targetIndex = direction === 'up' ? index - 1 : index + 1;
      if (targetIndex < 0 || targetIndex >= next.length) return prev;
      const temp = next[targetIndex];
      next[targetIndex] = next[index];
      next[index] = temp;
      return next;
    });
  }, []);

  // -- add step flow --------------------------------------------------------
  const openProfilePicker = useCallback(() => {
    setPendingProfile(null);
    setPendingEndCondition(END_OPTIONS[0].condition);
    setShowProfilePicker(true);
  }, []);

  const confirmAddStep = useCallback(() => {
    if (!pendingProfile) return;
    const newStep: SequenceStep = {
      id: uuid(),
      profile: pendingProfile,
      endCondition: pendingEndCondition,
    };
    setSteps((prev) => [...prev, newStep]);
    setShowProfilePicker(false);
    setPendingProfile(null);
  }, [pendingProfile, pendingEndCondition]);

  // -- save -----------------------------------------------------------------
  const handleSave = useCallback(() => {
    if (!isValid) return;
    const seq: SessionSequence = {
      id: existing?.id ?? uuid(),
      name: name.trim(),
      icon: existing?.icon ?? 'list.number',
      steps,
      transition,
      countdownSeconds: transition === 'autoAdvance' ? countdownSeconds : 0,
      createdAt: existing?.createdAt ?? new Date().toISOString(),
    };
    onSave(seq);
  }, [isValid, existing, name, steps, transition, countdownSeconds, onSave]);

  // =========================================================================
  // RENDER
  // =========================================================================

  return (
    <View style={styles.container}>
      {/* ── Header ──────────────────────────────────────────────── */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose} activeOpacity={0.7}>
          <Text style={styles.headerAction}>Cancel</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>
          {isEditing ? 'Edit Sequence' : 'New Sequence'}
        </Text>
        <TouchableOpacity
          onPress={handleSave}
          activeOpacity={0.7}
          disabled={!isValid}
        >
          <Text
            style={[
              styles.headerAction,
              styles.headerSave,
              !isValid && styles.headerActionDisabled,
            ]}
          >
            Save
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* ── NAME section ──────────────────────────────────────── */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>NAME</Text>
          <TextInput
            style={styles.textInput}
            value={name}
            onChangeText={setName}
            placeholder="Sequence name"
            placeholderTextColor={colors.secondaryText}
            returnKeyType="done"
            maxLength={60}
          />
        </View>

        {/* ── STEPS section ─────────────────────────────────────── */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>STEPS</Text>

          {steps.length === 0 && (
            <Text style={styles.emptyStepsText}>
              Add at least one step to build your sequence.
            </Text>
          )}

          {steps.map((step, index) => (
            <View key={step.id} style={styles.stepRow}>
              {/* Step number */}
              <View style={styles.stepNumber}>
                <Text style={styles.stepNumberText}>{index + 1}</Text>
              </View>

              {/* Profile icon + info */}
              <View style={styles.stepIconCircle}>
                <Ionicons
                  name={mapIcon(step.profile.icon)}
                  size={18}
                  color={colors.accent}
                />
              </View>
              <View style={styles.stepInfo}>
                <Text style={styles.stepName} numberOfLines={1}>
                  {step.profile.name}
                </Text>
                <Text style={styles.stepDetail}>
                  {formatInterval(step.profile.intervalSeconds)} interval
                  {' \u00B7 '}
                  {formatEndCondition(step.endCondition)}
                </Text>
              </View>

              {/* Reorder buttons */}
              <View style={styles.stepActions}>
                {index > 0 && (
                  <TouchableOpacity
                    onPress={() => moveStep(index, 'up')}
                    activeOpacity={0.6}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    accessibilityLabel={`Move step ${index + 1} up`}
                  >
                    <Ionicons
                      name="chevron-up"
                      size={18}
                      color={colors.secondaryText}
                    />
                  </TouchableOpacity>
                )}
                {index < steps.length - 1 && (
                  <TouchableOpacity
                    onPress={() => moveStep(index, 'down')}
                    activeOpacity={0.6}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                    accessibilityLabel={`Move step ${index + 1} down`}
                  >
                    <Ionicons
                      name="chevron-down"
                      size={18}
                      color={colors.secondaryText}
                    />
                  </TouchableOpacity>
                )}
              </View>

              {/* Remove */}
              <TouchableOpacity
                onPress={() => removeStep(step.id)}
                activeOpacity={0.6}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                accessibilityLabel={`Remove ${step.profile.name} step`}
              >
                <Ionicons
                  name="close-circle"
                  size={22}
                  color={colors.destructive}
                />
              </TouchableOpacity>
            </View>
          ))}

          {/* Add Step button */}
          <TouchableOpacity
            style={styles.addStepButton}
            onPress={openProfilePicker}
            activeOpacity={0.7}
          >
            <Ionicons name="add" size={16} color={colors.accent} />
            <Text style={styles.addStepText}>Add Step</Text>
          </TouchableOpacity>
        </View>

        {/* ── TRANSITION section ────────────────────────────────── */}
        <View style={styles.sectionCard}>
          <Text style={styles.sectionLabel}>TRANSITION</Text>
          <View style={styles.pillRow}>
            <TouchableOpacity
              style={[
                styles.transitionPill,
                transition === 'autoAdvance'
                  ? styles.pillActive
                  : styles.pillInactive,
              ]}
              onPress={() => setTransition('autoAdvance')}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.pillText,
                  transition === 'autoAdvance'
                    ? styles.pillTextActive
                    : styles.pillTextInactive,
                ]}
              >
                Auto Advance
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.transitionPill,
                transition === 'manual'
                  ? styles.pillActive
                  : styles.pillInactive,
              ]}
              onPress={() => setTransition('manual')}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.pillText,
                  transition === 'manual'
                    ? styles.pillTextActive
                    : styles.pillTextInactive,
                ]}
              >
                Manual
              </Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* ── COUNTDOWN section (auto-advance only) ─────────────── */}
        {transition === 'autoAdvance' && (
          <View style={styles.sectionCard}>
            <Text style={styles.sectionLabel}>COUNTDOWN BETWEEN STEPS</Text>
            <View style={styles.pillRow}>
              {COUNTDOWN_OPTIONS.map((sec) => (
                <TouchableOpacity
                  key={sec}
                  style={[
                    styles.countdownPill,
                    countdownSeconds === sec
                      ? styles.pillActive
                      : styles.pillInactive,
                  ]}
                  onPress={() => setCountdownSeconds(sec)}
                  activeOpacity={0.7}
                >
                  <Text
                    style={[
                      styles.pillText,
                      countdownSeconds === sec
                        ? styles.pillTextActive
                        : styles.pillTextInactive,
                    ]}
                  >
                    {sec}s
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        )}

        {/* Validation hint */}
        {steps.length > 0 && !steps.every(isStepValid) && (
          <Text style={styles.validationHint}>
            All steps must have a finite end condition (not unlimited).
          </Text>
        )}
      </ScrollView>

      {/* ── Profile Picker Modal ────────────────────────────────── */}
      <Modal
        visible={showProfilePicker}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowProfilePicker(false)}
      >
        <View style={styles.pickerContainer}>
          {/* Picker header */}
          <View style={styles.header}>
            <TouchableOpacity
              onPress={() => setShowProfilePicker(false)}
              activeOpacity={0.7}
            >
              <Text style={styles.headerAction}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.headerTitle}>
              {pendingProfile ? 'Set End Condition' : 'Choose Profile'}
            </Text>
            {pendingProfile ? (
              <TouchableOpacity
                onPress={confirmAddStep}
                activeOpacity={0.7}
              >
                <Text style={[styles.headerAction, styles.headerSave]}>
                  Add
                </Text>
              </TouchableOpacity>
            ) : (
              <View style={styles.headerPlaceholder} />
            )}
          </View>

          <ScrollView
            contentContainerStyle={styles.pickerScrollContent}
            showsVerticalScrollIndicator={false}
          >
            {!pendingProfile ? (
              /* ── Profile list ───────────────────────────────── */
              profiles.length === 0 ? (
                <View style={styles.pickerEmpty}>
                  <Text style={styles.pickerEmptyText}>
                    No presets available. Create a preset first.
                  </Text>
                </View>
              ) : (
                profiles.map((p) => (
                  <TouchableOpacity
                    key={p.id}
                    style={styles.pickerRow}
                    onPress={() => setPendingProfile(p)}
                    activeOpacity={0.7}
                  >
                    <View style={styles.stepIconCircle}>
                      <Ionicons
                        name={mapIcon(p.icon)}
                        size={20}
                        color={colors.accent}
                      />
                    </View>
                    <View style={styles.pickerRowInfo}>
                      <Text style={styles.pickerRowName}>{p.name}</Text>
                      <Text style={styles.pickerRowDetail}>
                        {formatInterval(p.intervalSeconds)} interval
                      </Text>
                    </View>
                    <Ionicons
                      name="chevron-forward"
                      size={14}
                      color={colors.secondaryText}
                    />
                  </TouchableOpacity>
                ))
              )
            ) : (
              /* ── End condition picker for selected profile ── */
              <View>
                <View style={styles.pickerSelectedProfile}>
                  <View style={styles.stepIconCircle}>
                    <Ionicons
                      name={mapIcon(pendingProfile.icon)}
                      size={20}
                      color={colors.accent}
                    />
                  </View>
                  <Text style={styles.pickerSelectedName}>
                    {pendingProfile.name}
                  </Text>
                </View>

                <Text style={styles.sectionLabel}>END CONDITION FOR THIS STEP</Text>
                <View style={styles.endConditionGrid}>
                  {END_OPTIONS.map((opt) => {
                    const isActive = endConditionsEqual(
                      pendingEndCondition,
                      opt.condition,
                    );
                    return (
                      <TouchableOpacity
                        key={opt.label}
                        style={[
                          styles.endPill,
                          isActive ? styles.pillActive : styles.pillInactive,
                        ]}
                        onPress={() => setPendingEndCondition(opt.condition)}
                        activeOpacity={0.7}
                      >
                        <Text
                          style={[
                            styles.pillText,
                            isActive
                              ? styles.pillTextActive
                              : styles.pillTextInactive,
                          ]}
                        >
                          {opt.label}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>
              </View>
            )}
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

// ===========================================================================
// Styles
// ===========================================================================

const { width: SCREEN_WIDTH } = Dimensions.get('window');

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
    paddingHorizontal: spacing.md,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
  },
  headerTitle: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
  },
  headerAction: {
    fontSize: fontSize.md,
    color: colors.accent,
    fontWeight: '500',
  },
  headerSave: {
    fontWeight: '600',
  },
  headerActionDisabled: {
    color: colors.secondaryText,
    opacity: 0.5,
  },
  headerPlaceholder: {
    width: 40,
  },

  // Scroll
  scrollContent: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    paddingBottom: 40,
  },

  // Section cards
  sectionCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    marginBottom: 12,
  },
  sectionLabel: {
    fontSize: fontSize.xs,
    fontWeight: '600',
    letterSpacing: 1.2,
    color: colors.secondaryText,
    textTransform: 'uppercase',
    marginBottom: 10,
  },

  // Text input
  textInput: {
    fontSize: fontSize.lg,
    color: colors.primary,
    paddingVertical: 8,
    paddingHorizontal: 0,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.pillBackground,
  },

  // Steps
  emptyStepsText: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    textAlign: 'center',
    paddingVertical: spacing.md,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.pillBackground,
  },
  stepNumber: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.pillBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  stepNumberText: {
    fontSize: fontSize.sm,
    fontWeight: '600',
    color: colors.secondaryText,
  },
  stepIconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.pillBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  stepInfo: {
    flex: 1,
    marginRight: 4,
  },
  stepName: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 2,
  },
  stepDetail: {
    fontSize: fontSize.xs,
    color: colors.secondaryText,
  },
  stepActions: {
    flexDirection: 'column',
    alignItems: 'center',
    marginRight: 8,
  },

  // Add Step button
  addStepButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    marginTop: 4,
    gap: 4,
  },
  addStepText: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.accent,
  },

  // Transition pills
  pillRow: {
    flexDirection: 'row',
    gap: 8,
  },
  transitionPill: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  countdownPill: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pillActive: {
    backgroundColor: colors.primary,
  },
  pillInactive: {
    backgroundColor: colors.pillBackground,
  },
  pillText: {
    fontSize: fontSize.md,
    fontWeight: '500',
  },
  pillTextActive: {
    color: colors.onAccent,
  },
  pillTextInactive: {
    color: colors.primary,
  },

  // Validation
  validationHint: {
    fontSize: fontSize.sm,
    color: colors.destructive,
    textAlign: 'center',
    marginTop: 4,
    marginBottom: 12,
  },

  // ── Profile Picker Modal ──────────────────────────────────────
  pickerContainer: {
    flex: 1,
    backgroundColor: colors.background,
  },
  pickerScrollContent: {
    paddingHorizontal: spacing.md,
    paddingBottom: 40,
  },
  pickerEmpty: {
    alignItems: 'center',
    paddingVertical: spacing.xl,
  },
  pickerEmptyText: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    textAlign: 'center',
  },
  pickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  pickerRowInfo: {
    flex: 1,
  },
  pickerRowName: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 2,
  },
  pickerRowDetail: {
    fontSize: fontSize.xs,
    color: colors.secondaryText,
  },

  // Selected profile in picker
  pickerSelectedProfile: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.sm,
    marginBottom: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.pillBackground,
  },
  pickerSelectedName: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
  },

  // End condition grid
  endConditionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  endPill: {
    width: (SCREEN_WIDTH - 32 - 24 - 16) / 3,
    paddingVertical: 12,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
