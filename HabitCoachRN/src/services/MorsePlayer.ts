import { Platform, Vibration } from 'react-native';
import * as Haptics from 'expo-haptics';

const UNIT_MS = 120;

const MORSE_TABLE: Record<string, string> = {
  A: '.-',    B: '-...',  C: '-.-.',  D: '-..',
  E: '.',     F: '..-.',  G: '--.',   H: '....',
  I: '..',    J: '.---',  K: '-.-',   L: '.-..',
  M: '--',    N: '-.',    O: '---',   P: '.--.',
  Q: '--.-',  R: '.-.',   S: '...',   T: '-',
  U: '..-',   V: '...-',  W: '.--',   X: '-..-',
  Y: '-.--',  Z: '--..',
  '0': '-----', '1': '.----', '2': '..---', '3': '...--',
  '4': '....-', '5': '.....', '6': '-....', '7': '--...',
  '8': '---..', '9': '----.',
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function playMorse(word: string, signal: { cancelled: boolean }): Promise<void> {
  const chars = word
    .toUpperCase()
    .split('')
    .filter((c) => c in MORSE_TABLE);
  if (chars.length === 0) return;

  for (let ci = 0; ci < chars.length; ci++) {
    if (signal.cancelled) return;
    const code = MORSE_TABLE[chars[ci]];
    if (!code) continue;

    for (let ei = 0; ei < code.length; ei++) {
      if (signal.cancelled) return;
      const isDash = code[ei] === '-';

      // Play haptic — heavy for dash, light for dot
      if (Platform.OS === 'android') {
        Vibration.vibrate(isDash ? 200 : 60);
      } else if (isDash) {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      } else {
        await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }

      // Wait for element duration
      const tapDuration = isDash ? UNIT_MS * 3 : UNIT_MS;
      await sleep(tapDuration);

      // Intra-character gap
      if (ei < code.length - 1) {
        await sleep(UNIT_MS);
      }
    }

    // Inter-character gap
    if (ci < chars.length - 1) {
      await sleep(UNIT_MS * 3);
    }
  }
}

export function estimatedDuration(word: string): number {
  const chars = word
    .toUpperCase()
    .split('')
    .filter((c) => c in MORSE_TABLE);
  if (chars.length === 0) return 0;

  let units = 0;
  for (let i = 0; i < chars.length; i++) {
    const code = MORSE_TABLE[chars[i]];
    if (!code) continue;
    for (let j = 0; j < code.length; j++) {
      units += code[j] === '-' ? 3 : 1;
      if (j < code.length - 1) units += 1; // intra-char gap
    }
    if (i < chars.length - 1) units += 3; // inter-char gap
  }
  return units * 0.12;
}

export function defaultMorseWord(name: string): string {
  const alpha = name.replace(/[^a-zA-Z]/g, '');
  return alpha.slice(0, 4).toUpperCase();
}
