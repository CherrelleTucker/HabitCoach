import React, { useState, useRef, useCallback, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  AppState,
  Platform,
} from 'react-native';
import { colors, spacing, fontSize } from '../services/theme';
import { TimerService, TimerState } from '../services/TimerService';
import { playHaptic, playRandomHaptic } from '../services/HapticService';
import { playMorse } from '../services/MorsePlayer';
import {
  SessionSequence,
  SessionEndCondition,
  Session,
  SessionSettings,
  DEFAULT_SETTINGS,
  formatEndCondition,
  resolvedHapticMode,
  resolvedHapticPattern,
  resolvedMorseWord,
  HapticMode,
} from '../models/types';
import { v4 as uuid } from '../models/uuid';
import * as Storage from '../services/StorageService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type Phase = 'running' | 'countdown' | 'complete';

interface StepRecord {
  stepIndex: number;
  profileName: string;
  startedAt: string;
  endedAt: string;
  reminderCount: number;
  intervalSeconds: number;
  varianceSeconds: number;
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
  sequence: SessionSequence;
  onComplete: () => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatTimer(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
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

function totalCountForCondition(
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

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function SequenceTimerScreen({ sequence, onComplete }: Props) {
  // -- state ----------------------------------------------------------------
  const [phase, setPhase] = useState<Phase>('running');
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [timerState, setTimerState] = useState<TimerState>({
    isRunning: false,
    elapsedSeconds: 0,
    reminderCount: 0,
    secondsUntilNextBuzz: 0,
    isComplete: false,
  });
  const [countdownValue, setCountdownValue] = useState(sequence.countdownSeconds);
  const [settings, setSettings] = useState<SessionSettings>(DEFAULT_SETTINGS);
  const [completedStepRecords, setCompletedStepRecords] = useState<StepRecord[]>([]);

  // -- refs -----------------------------------------------------------------
  const timerRef = useRef<TimerService | null>(null);
  const morseSignalRef = useRef({ cancelled: false });
  const stepStartRef = useRef<Date>(new Date());
  const countdownTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const totalElapsedRef = useRef(0);

  // -- derived --------------------------------------------------------------
  const currentStep = sequence.steps[currentStepIndex];
  const totalSteps = sequence.steps.length;
  const isLastStep = currentStepIndex >= totalSteps - 1;

  // -- load settings --------------------------------------------------------
  useEffect(() => {
    Storage.loadSettings().then(setSettings);
  }, []);

  // -- background handling --------------------------------------------------
  useEffect(() => {
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        timerRef.current?.resumeFromBackground();
      }
    });
    return () => sub.remove();
  }, []);

  // -- haptic callback for current step ------------------------------------
  const handleBuzz = useCallback(() => {
    if (!currentStep) return;
    const profile = currentStep.profile;
    const mode: HapticMode = resolvedHapticMode(profile, settings);

    if (mode === 'morse') {
      const word = resolvedMorseWord(profile);
      morseSignalRef.current = { cancelled: false };
      playMorse(word, morseSignalRef.current);
    } else if (mode === 'randomized') {
      playRandomHaptic();
    } else {
      const pattern = resolvedHapticPattern(profile, settings);
      playHaptic(pattern);
    }
  }, [currentStep, settings]);

  // -- save a step session record ------------------------------------------
  const saveStepRecord = useCallback(
    async (
      stepIdx: number,
      startedAt: Date,
      reminderCount: number,
      wasCancelled: boolean,
    ) => {
      const step = sequence.steps[stepIdx];
      if (!step) return;

      const now = new Date();
      const session: Session = {
        id: uuid(),
        profileId: step.profile.id,
        profileName: step.profile.name,
        startedAt: startedAt.toISOString(),
        endedAt: now.toISOString(),
        intervalSeconds: step.profile.intervalSeconds,
        varianceSeconds: step.profile.varianceSeconds,
        reminderCount,
        wasCancelled,
        sequenceId: sequence.id,
        sequenceIndex: stepIdx,
        sequenceName: sequence.name,
      };
      await Storage.addSession(session);

      if (!wasCancelled) {
        const record: StepRecord = {
          stepIndex: stepIdx,
          profileName: step.profile.name,
          startedAt: startedAt.toISOString(),
          endedAt: now.toISOString(),
          reminderCount,
          intervalSeconds: step.profile.intervalSeconds,
          varianceSeconds: step.profile.varianceSeconds,
        };
        setCompletedStepRecords((prev) => [...prev, record]);
      }
    },
    [sequence],
  );

  // -- advance to next step or complete ------------------------------------
  const advanceToNextStep = useCallback(() => {
    if (isLastStep) {
      // Sequence complete
      morseSignalRef.current.cancelled = true;
      timerRef.current?.stop();
      setPhase('complete');
      return;
    }

    const nextIndex = currentStepIndex + 1;

    if (sequence.transition === 'autoAdvance' && sequence.countdownSeconds > 0) {
      // Show countdown before next step
      setPhase('countdown');
      setCountdownValue(sequence.countdownSeconds);

      countdownTimerRef.current = setInterval(() => {
        setCountdownValue((prev) => {
          if (prev <= 1) {
            // Countdown done -- start next step
            if (countdownTimerRef.current) {
              clearInterval(countdownTimerRef.current);
              countdownTimerRef.current = null;
            }
            setCurrentStepIndex(nextIndex);
            setPhase('running');
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } else {
      // Immediate advance (manual or zero countdown)
      setCurrentStepIndex(nextIndex);
      setPhase('running');
    }
  }, [currentStepIndex, isLastStep, sequence]);

  // -- step completion handler ---------------------------------------------
  const handleStepComplete = useCallback(() => {
    const timer = timerRef.current;
    const reminderCount = timer?.state.reminderCount ?? 0;

    // Track total elapsed across all steps
    totalElapsedRef.current += timer?.state.elapsedSeconds ?? 0;

    saveStepRecord(currentStepIndex, stepStartRef.current, reminderCount, false);
    advanceToNextStep();
  }, [currentStepIndex, saveStepRecord, advanceToNextStep]);

  // -- start / reconfigure timer for current step --------------------------
  useEffect(() => {
    if (phase !== 'running' || !currentStep) return;

    morseSignalRef.current.cancelled = true;
    stepStartRef.current = new Date();

    const step = currentStep;
    const config = {
      intervalSeconds: step.profile.intervalSeconds,
      varianceSeconds: step.profile.varianceSeconds,
      endCondition: step.endCondition,
      onInterval: handleBuzz,
      onComplete: handleStepComplete,
    };

    if (timerRef.current && timerRef.current.state.isRunning) {
      // Reconfigure existing timer for seamless transition
      timerRef.current.reconfigure(config);
    } else {
      // Create new timer
      const timer = new TimerService((newState) => {
        setTimerState(newState);
      });
      timerRef.current = timer;
      timer.start(config);
    }

    // Update the callbacks when they change -- reconfigure handles this
    // by keeping the timer running but swapping the config
  }, [phase, currentStepIndex, currentStep, handleBuzz, handleStepComplete]);

  // -- cleanup on unmount --------------------------------------------------
  useEffect(() => {
    return () => {
      morseSignalRef.current.cancelled = true;
      timerRef.current?.stop();
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
    };
  }, []);

  // -- cancel sequence -----------------------------------------------------
  const handleCancel = useCallback(() => {
    morseSignalRef.current.cancelled = true;

    if (countdownTimerRef.current) {
      clearInterval(countdownTimerRef.current);
      countdownTimerRef.current = null;
    }

    const timer = timerRef.current;
    if (timer) {
      saveStepRecord(
        currentStepIndex,
        stepStartRef.current,
        timer.state.reminderCount,
        true,
      );
      timer.stop();
    }

    onComplete();
  }, [currentStepIndex, saveStepRecord, onComplete]);

  // -- progress calculations -----------------------------------------------
  const stepProgress = useMemo(() => {
    if (phase !== 'running' || !currentStep) return null;

    const totalSec = totalSecondsForCondition(currentStep.endCondition);
    if (totalSec != null && totalSec > 0) {
      return Math.min(1, timerState.elapsedSeconds / totalSec);
    }

    const totalCount = totalCountForCondition(
      currentStep.endCondition,
      currentStep.profile.intervalSeconds,
    );
    if (totalCount != null && totalCount > 0) {
      return Math.min(1, timerState.reminderCount / totalCount);
    }

    return null;
  }, [phase, currentStep, timerState.elapsedSeconds, timerState.reminderCount]);

  const overallProgress = useMemo(() => {
    // Each completed step counts as 1, current step contributes partial
    const completedFraction = currentStepIndex / totalSteps;
    const currentFraction = (stepProgress ?? 0) / totalSteps;
    return Math.min(1, completedFraction + currentFraction);
  }, [currentStepIndex, totalSteps, stepProgress]);

  // -- completion stats ----------------------------------------------------
  const completionStats = useMemo(() => {
    if (phase !== 'complete') return null;

    let totalDurationSec = 0;
    let totalReminders = 0;
    for (const record of completedStepRecords) {
      const dur =
        (new Date(record.endedAt).getTime() -
          new Date(record.startedAt).getTime()) /
        1000;
      totalDurationSec += dur;
      totalReminders += record.reminderCount;
    }

    return {
      duration: formatTimer(Math.floor(totalDurationSec)),
      totalReminders,
      stepsCompleted: completedStepRecords.length,
    };
  }, [phase, completedStepRecords]);

  // =========================================================================
  // RENDER
  // =========================================================================

  // -- Completion View ------------------------------------------------------
  if (phase === 'complete' && completionStats) {
    return (
      <View style={styles.container}>
        <View style={styles.centerContent}>
          <Text style={styles.completionIcon}>{'\u2705'}</Text>
          <Text style={styles.completionTitle}>Sequence Complete</Text>
          <Text style={styles.completionSubtitle}>{sequence.name}</Text>

          {/* Stats card */}
          <View style={styles.statsCard}>
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Total Duration</Text>
              <Text style={styles.statsValue}>{completionStats.duration}</Text>
            </View>
            <View style={styles.statsDivider} />
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Total Reminders</Text>
              <Text style={styles.statsValue}>
                {completionStats.totalReminders}
              </Text>
            </View>
            <View style={styles.statsDivider} />
            <View style={styles.statsRow}>
              <Text style={styles.statsLabel}>Steps Completed</Text>
              <Text style={styles.statsValue}>
                {completionStats.stepsCompleted} of {totalSteps}
              </Text>
            </View>
          </View>

          {/* Per-step breakdown */}
          {completedStepRecords.length > 1 && (
            <View style={styles.breakdownCard}>
              {completedStepRecords.map((record, idx) => {
                const dur = Math.floor(
                  (new Date(record.endedAt).getTime() -
                    new Date(record.startedAt).getTime()) /
                    1000,
                );
                return (
                  <View key={idx} style={styles.breakdownRow}>
                    <View style={styles.breakdownNumber}>
                      <Text style={styles.breakdownNumberText}>
                        {record.stepIndex + 1}
                      </Text>
                    </View>
                    <Text style={styles.breakdownName} numberOfLines={1}>
                      {record.profileName}
                    </Text>
                    <Text style={styles.breakdownStat}>
                      {formatTimer(dur)} / {record.reminderCount}x
                    </Text>
                  </View>
                );
              })}
            </View>
          )}

          {/* Done button */}
          <TouchableOpacity
            style={styles.accentButton}
            onPress={onComplete}
            activeOpacity={0.8}
          >
            <Text style={styles.accentButtonText}>Done</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  // -- Countdown between steps ----------------------------------------------
  if (phase === 'countdown') {
    const nextStep = sequence.steps[currentStepIndex + 1];
    return (
      <View style={styles.container}>
        <View style={styles.centerContent}>
          <Text style={styles.countdownLabel}>Next Step</Text>
          <Text style={styles.countdownNextName}>
            {nextStep?.profile.name ?? 'Next'}
          </Text>
          <Text style={styles.countdownNumber}>{countdownValue}</Text>
          <Text style={styles.countdownHint}>
            Step {currentStepIndex + 2} of {totalSteps}
          </Text>
        </View>
      </View>
    );
  }

  // -- Running (active step) ------------------------------------------------
  return (
    <View style={styles.container}>
      <View style={styles.activeContent}>
        {/* Header info */}
        <Text style={styles.sequenceName}>{sequence.name}</Text>
        <Text style={styles.stepIndicator}>
          Step {currentStepIndex + 1} of {totalSteps}
        </Text>
        <Text style={styles.currentProfileName}>
          {currentStep?.profile.name ?? ''}
        </Text>

        {/* Big elapsed timer */}
        <Text style={styles.elapsedTimer}>
          {formatTimer(timerState.elapsedSeconds)}
        </Text>

        {/* Reminder count + next buzz */}
        <Text style={styles.activeSubtext}>
          {timerState.reminderCount} reminder
          {timerState.reminderCount !== 1 ? 's' : ''} {'\u00B7'} next in ~
          {timerState.secondsUntilNextBuzz}s
        </Text>

        {/* Overall sequence progress */}
        <View style={styles.progressSection}>
          <Text style={styles.progressSectionLabel}>Sequence</Text>
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                { width: `${Math.round(overallProgress * 100)}%` },
              ]}
            />
          </View>
        </View>

        {/* Current step progress */}
        {stepProgress != null && (
          <View style={styles.progressSection}>
            <Text style={styles.progressSectionLabel}>This Step</Text>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFillStep,
                  { width: `${Math.round(stepProgress * 100)}%` },
                ]}
              />
            </View>
          </View>
        )}

        {/* End condition label */}
        {currentStep && (
          <Text style={styles.endConditionLabel}>
            {formatEndCondition(currentStep.endCondition)}
          </Text>
        )}

        {/* Cancel Sequence button */}
        <TouchableOpacity
          style={styles.cancelButton}
          onPress={handleCancel}
          activeOpacity={0.8}
        >
          <Text style={styles.cancelButtonText}>Cancel Sequence</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ===========================================================================
// Styles
// ===========================================================================

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  activeContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  centerContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },

  // -- Header info ----------------------------------------------------------
  sequenceName: {
    fontSize: fontSize.md,
    fontWeight: '500',
    color: colors.secondaryText,
    marginBottom: 2,
  },
  stepIndicator: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
    marginBottom: spacing.sm,
  },
  currentProfileName: {
    fontSize: fontSize.xl,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: spacing.lg,
  },

  // -- Timer ----------------------------------------------------------------
  elapsedTimer: {
    fontSize: 72,
    fontWeight: '300',
    fontVariant: ['tabular-nums'],
    color: colors.accent,
    marginBottom: 8,
    ...(Platform.OS === 'ios'
      ? { fontFamily: 'Menlo' }
      : { fontFamily: 'monospace' }),
  },
  activeSubtext: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    marginBottom: spacing.lg,
  },

  // -- Progress bars --------------------------------------------------------
  progressSection: {
    width: '100%',
    paddingHorizontal: 20,
    marginBottom: 12,
  },
  progressSectionLabel: {
    fontSize: fontSize.xs,
    fontWeight: '600',
    letterSpacing: 1,
    color: colors.secondaryText,
    textTransform: 'uppercase',
    marginBottom: 4,
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
  progressFillStep: {
    height: '100%',
    borderRadius: 4,
    backgroundColor: colors.success,
  },

  // -- End condition label --------------------------------------------------
  endConditionLabel: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
    marginTop: spacing.sm,
    marginBottom: spacing.xl,
  },

  // -- Cancel button --------------------------------------------------------
  cancelButton: {
    backgroundColor: colors.destructive,
    paddingVertical: 16,
    borderRadius: 14,
    width: '100%',
    alignItems: 'center',
    marginHorizontal: 20,
  },
  cancelButtonText: {
    color: colors.onAccent,
    fontSize: fontSize.lg,
    fontWeight: '600',
  },

  // -- Countdown between steps ----------------------------------------------
  countdownLabel: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    marginBottom: 4,
  },
  countdownNextName: {
    fontSize: fontSize.xl,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: spacing.lg,
  },
  countdownNumber: {
    fontSize: 96,
    fontWeight: '200',
    fontVariant: ['tabular-nums'],
    color: colors.accent,
    marginBottom: spacing.md,
    ...(Platform.OS === 'ios'
      ? { fontFamily: 'Menlo' }
      : { fontFamily: 'monospace' }),
  },
  countdownHint: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
  },

  // -- Completion view ------------------------------------------------------
  completionIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  completionTitle: {
    fontSize: fontSize.xxl,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: 4,
  },
  completionSubtitle: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    marginBottom: spacing.lg,
  },
  statsCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 16,
    width: '100%',
    marginBottom: 16,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  statsLabel: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
  },
  statsValue: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.primary,
  },
  statsDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.pillBackground,
  },

  // -- Per-step breakdown ---------------------------------------------------
  breakdownCard: {
    backgroundColor: colors.cardBackground,
    borderRadius: 12,
    padding: 12,
    width: '100%',
    marginBottom: spacing.lg,
  },
  breakdownRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
  },
  breakdownNumber: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.pillBackground,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  breakdownNumberText: {
    fontSize: fontSize.sm,
    fontWeight: '600',
    color: colors.secondaryText,
  },
  breakdownName: {
    flex: 1,
    fontSize: fontSize.md,
    fontWeight: '500',
    color: colors.primary,
  },
  breakdownStat: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
    marginLeft: 8,
  },

  // -- Done button ----------------------------------------------------------
  accentButton: {
    backgroundColor: colors.accent,
    paddingVertical: 16,
    borderRadius: 14,
    width: '100%',
    alignItems: 'center',
  },
  accentButtonText: {
    color: colors.onAccent,
    fontSize: fontSize.lg,
    fontWeight: '600',
  },
});
