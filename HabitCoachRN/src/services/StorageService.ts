import AsyncStorage from '@react-native-async-storage/async-storage';
import { SessionProfile, Session, SessionSettings, SessionSequence, DEFAULT_SETTINGS } from '../models/types';

const KEYS = {
  profiles: 'habitcoach_profiles',
  sessions: 'habitcoach_sessions',
  settings: 'habitcoach_settings',
  sequences: 'habitcoach_sequences',
  isPremium: 'habitcoach_is_premium',
};

// Profiles

export async function loadProfiles(): Promise<SessionProfile[]> {
  const json = await AsyncStorage.getItem(KEYS.profiles);
  return json ? JSON.parse(json) : [];
}

export async function saveProfiles(profiles: SessionProfile[]): Promise<void> {
  await AsyncStorage.setItem(KEYS.profiles, JSON.stringify(profiles));
}

// Sessions (history)

export async function loadSessions(): Promise<Session[]> {
  const json = await AsyncStorage.getItem(KEYS.sessions);
  return json ? JSON.parse(json) : [];
}

export async function saveSessions(sessions: Session[]): Promise<void> {
  await AsyncStorage.setItem(KEYS.sessions, JSON.stringify(sessions));
}

export async function addSession(session: Session): Promise<void> {
  const sessions = await loadSessions();
  sessions.unshift(session);
  await saveSessions(sessions);
}

// Settings

export async function loadSettings(): Promise<SessionSettings> {
  const json = await AsyncStorage.getItem(KEYS.settings);
  return json ? { ...DEFAULT_SETTINGS, ...JSON.parse(json) } : DEFAULT_SETTINGS;
}

export async function saveSettings(settings: SessionSettings): Promise<void> {
  await AsyncStorage.setItem(KEYS.settings, JSON.stringify(settings));
}

// Sequences

export async function loadSequences(): Promise<SessionSequence[]> {
  const json = await AsyncStorage.getItem(KEYS.sequences);
  return json ? JSON.parse(json) : [];
}

export async function saveSequences(sequences: SessionSequence[]): Promise<void> {
  await AsyncStorage.setItem(KEYS.sequences, JSON.stringify(sequences));
}

// Premium

export async function loadPremiumStatus(): Promise<boolean> {
  const val = await AsyncStorage.getItem(KEYS.isPremium);
  return val === 'true';
}

export async function savePremiumStatus(isPremium: boolean): Promise<void> {
  await AsyncStorage.setItem(KEYS.isPremium, isPremium ? 'true' : 'false');
}
