import { Platform, Vibration } from 'react-native';
import * as Haptics from 'expo-haptics';
import { HapticPattern } from '../models/types';

// On iOS, expo-haptics uses the Taptic Engine which is rich and textured.
// On Android, expo-haptics is too subtle for workout reminders.
// We use the Vibration API on Android for perceptible buzzes.

// Android vibration patterns: [pause, vibrate, pause, vibrate, ...]
// All patterns use strong durations — Android haptic motors need
// longer pulses than iOS Taptic Engine to be perceptible.
const ANDROID_PATTERNS: Record<HapticPattern, number[]> = {
  notification: [0, 300, 100, 300],        // Strong double-tap
  click:        [0, 200],                   // Solid single tap
  success:      [0, 200, 100, 200, 100, 400], // Triple pulse (celebration)
  directionUp:  [0, 250, 100, 250],        // Medium double-tap
  retry:        [0, 500],                   // Long single buzz
};

const IOS_PATTERN_MAP: Record<HapticPattern, () => Promise<void>> = {
  notification: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning),
  click: () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light),
  success: () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success),
  directionUp: () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium),
  retry: () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy),
};

export async function playHaptic(pattern: HapticPattern): Promise<void> {
  if (Platform.OS === 'android') {
    Vibration.vibrate(ANDROID_PATTERNS[pattern]);
  } else {
    const play = IOS_PATTERN_MAP[pattern];
    if (play) await play();
  }
}

export async function playRandomHaptic(): Promise<void> {
  const patterns: HapticPattern[] = ['notification', 'click', 'success', 'directionUp', 'retry'];
  const random = patterns[Math.floor(Math.random() * patterns.length)];
  await playHaptic(random);
}
