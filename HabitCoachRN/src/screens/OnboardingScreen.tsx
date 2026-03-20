import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Dimensions,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { colors, spacing, fontSize } from '../services/theme';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const PAGE_COUNT = 4;

interface Props {
  onComplete: () => void;
}

// ---------- Page data ----------

function WelcomePage() {
  return (
    <View style={styles.pageContent}>
      <Text style={styles.largeIcon}>{'\u3030\uFE0F'}</Text>
      <Text style={styles.title}>HabitCoach</Text>
      <Text style={styles.subtitle}>Haptic reminders that keep you on track</Text>
    </View>
  );
}

function HowItWorksPage() {
  const steps = [
    { icon: '\uD83D\uDCCB', text: 'Pick a preset or configure a quick session' },
    { icon: '\u25B6\uFE0F', text: 'Start your session' },
    { icon: '\uD83D\uDCF1', text: 'Your device buzzes at each interval' },
    { icon: '\u231A', text: 'Pair a smartwatch for wrist haptics on the go' },
  ];

  return (
    <View style={styles.pageContent}>
      <Text style={styles.sectionTitle}>How it works</Text>
      {steps.map((step, i) => (
        <View key={i} style={styles.stepRow}>
          <Text style={styles.stepIcon}>{step.icon}</Text>
          <Text style={styles.stepText}>{step.text}</Text>
        </View>
      ))}
    </View>
  );
}

function WhyRandomizedPage() {
  return (
    <View style={styles.pageContent}>
      <Text style={styles.mediumIcon}>{'\uD83D\uDD00'}</Text>
      <Text style={styles.title}>Why randomized?</Text>
      <Text style={styles.bodyText}>
        Your body naturally adapts to repeated stimuli and tunes them out. HabitCoach varies haptic
        patterns by default so each buzz stays noticeable.
      </Text>
    </View>
  );
}

function GetStartedPage({ onComplete }: { onComplete: () => void }) {
  return (
    <View style={styles.pageContent}>
      <Text style={styles.checkIcon}>{'\u2705'}</Text>
      <Text style={styles.title}>You're all set</Text>
      <Text style={styles.bodyText}>
        Set up your first preset or jump right into a quick session.
      </Text>
      <Pressable style={styles.getStartedButton} onPress={onComplete}>
        <Text style={styles.getStartedButtonText}>Get Started</Text>
      </Pressable>
    </View>
  );
}

// ---------- Page dots ----------

function PageDots({ current }: { current: number }) {
  return (
    <View style={styles.dotsContainer}>
      {Array.from({ length: PAGE_COUNT }).map((_, i) => (
        <View
          key={i}
          style={[styles.dot, i === current ? styles.dotActive : styles.dotInactive]}
        />
      ))}
    </View>
  );
}

// ---------- Main component ----------

export default function OnboardingScreen({ onComplete }: Props) {
  const scrollRef = useRef<ScrollView>(null);
  const [currentPage, setCurrentPage] = useState(0);

  const handleScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const page = Math.round(e.nativeEvent.contentOffset.x / SCREEN_WIDTH);
    setCurrentPage(page);
  };

  const goNext = () => {
    const next = Math.min(currentPage + 1, PAGE_COUNT - 1);
    scrollRef.current?.scrollTo({ x: next * SCREEN_WIDTH, animated: true });
    setCurrentPage(next);
  };

  return (
    <View style={styles.container}>
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        scrollEventThrottle={16}
      >
        <View style={styles.page}>
          <WelcomePage />
        </View>
        <View style={styles.page}>
          <HowItWorksPage />
        </View>
        <View style={styles.page}>
          <WhyRandomizedPage />
        </View>
        <View style={styles.page}>
          <GetStartedPage onComplete={onComplete} />
        </View>
      </ScrollView>

      <View style={styles.footer}>
        <PageDots current={currentPage} />
        {currentPage < PAGE_COUNT - 1 && (
          <Pressable onPress={goNext} style={styles.nextButton}>
            <Text style={styles.nextButtonText}>Next</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

// ---------- Styles ----------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  page: {
    width: SCREEN_WIDTH,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
  },
  pageContent: {
    alignItems: 'center',
    width: '100%',
    paddingHorizontal: spacing.md,
  },
  largeIcon: {
    fontSize: 80,
    marginBottom: spacing.lg,
  },
  mediumIcon: {
    fontSize: 50,
    marginBottom: spacing.lg,
  },
  checkIcon: {
    fontSize: 60,
    marginBottom: spacing.lg,
  },
  title: {
    fontSize: fontSize.xxl,
    fontWeight: 'bold',
    color: colors.primary,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  sectionTitle: {
    fontSize: fontSize.xl,
    fontWeight: 'bold',
    color: colors.primary,
    textAlign: 'center',
    marginBottom: spacing.lg,
  },
  subtitle: {
    fontSize: fontSize.lg,
    color: colors.secondaryText,
    textAlign: 'center',
  },
  bodyText: {
    fontSize: fontSize.lg,
    color: colors.secondaryText,
    textAlign: 'center',
    lineHeight: 24,
    marginTop: spacing.sm,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.md,
    width: '100%',
    paddingHorizontal: spacing.md,
  },
  stepIcon: {
    fontSize: 24,
    marginRight: spacing.md,
    width: 32,
    textAlign: 'center',
  },
  stepText: {
    fontSize: fontSize.lg,
    color: colors.primary,
    flex: 1,
  },
  footer: {
    alignItems: 'center',
    paddingBottom: spacing.xxl,
    paddingTop: spacing.md,
  },
  dotsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginHorizontal: 4,
  },
  dotActive: {
    backgroundColor: colors.accent,
  },
  dotInactive: {
    backgroundColor: colors.pillBackground,
  },
  nextButton: {
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.lg,
  },
  nextButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.accent,
  },
  getStartedButton: {
    marginTop: spacing.xl,
    backgroundColor: colors.accent,
    borderRadius: 999,
    paddingVertical: spacing.md,
    alignSelf: 'stretch',
    alignItems: 'center',
  },
  getStartedButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.onAccent,
  },
});
