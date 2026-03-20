import React, { createContext, useContext, useEffect, useState, useCallback, useMemo } from 'react';
import {
  SessionProfile,
  Session,
  SessionSequence,
  SessionSettings,
  DEFAULT_SETTINGS,
} from '../models/types';
import { PROFILE_TEMPLATES } from '../models/templates';
import * as Storage from './StorageService';
import { setTheme } from './theme';

// ---------------------------------------------------------------------------
// Context shape
// ---------------------------------------------------------------------------

interface AppContextValue {
  // Profiles
  profiles: SessionProfile[];
  templateProfiles: SessionProfile[];
  allProfiles: SessionProfile[]; // user profiles + templates merged
  saveProfile: (profile: SessionProfile) => Promise<void>;
  deleteProfile: (id: string) => Promise<void>;

  // Sessions (history)
  sessions: Session[];
  addSession: (session: Session) => Promise<void>;
  clearSessions: () => Promise<void>;

  // Sequences
  sequences: SessionSequence[];
  saveSequence: (sequence: SessionSequence) => Promise<void>;
  deleteSequence: (id: string) => Promise<void>;

  // Settings
  settings: SessionSettings;
  saveSettings: (settings: SessionSettings) => Promise<void>;

  // Premium
  isPremium: boolean;
  unlockPremium: () => Promise<void>;

  // Loading flag
  isLoading: boolean;
}

const AppContext = createContext<AppContextValue | undefined>(undefined);

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [profiles, setProfiles] = useState<SessionProfile[]>([]);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [sequences, setSequences] = useState<SessionSequence[]>([]);
  const [settings, setSettings] = useState<SessionSettings>(DEFAULT_SETTINGS);
  const [isPremium, setIsPremium] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  // Load everything on mount
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [p, sess, seq, sett, prem] = await Promise.all([
        Storage.loadProfiles(),
        Storage.loadSessions(),
        Storage.loadSequences(),
        Storage.loadSettings(),
        Storage.loadPremiumStatus(),
      ]);
      if (cancelled) return;
      if (sett.theme) {
        setTheme(sett.theme);
      }
      setProfiles(p);
      setSessions(sess);
      setSequences(seq);
      setSettings(sett);
      setIsPremium(prem);
      setIsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // --- Profiles ---

  const saveProfile = useCallback(async (profile: SessionProfile) => {
    setProfiles((prev) => {
      const idx = prev.findIndex((p) => p.id === profile.id);
      const next = idx >= 0 ? prev.map((p) => (p.id === profile.id ? profile : p)) : [...prev, profile];
      Storage.saveProfiles(next);
      return next;
    });
  }, []);

  const deleteProfile = useCallback(async (id: string) => {
    setProfiles((prev) => {
      const next = prev.filter((p) => p.id !== id);
      Storage.saveProfiles(next);
      return next;
    });
  }, []);

  const templateProfiles = useMemo(() => PROFILE_TEMPLATES, []);

  const allProfiles = useMemo(
    () => [...profiles, ...templateProfiles],
    [profiles, templateProfiles],
  );

  // --- Sessions ---

  const addSessionCb = useCallback(async (session: Session) => {
    setSessions((prev) => {
      const next = [session, ...prev];
      Storage.saveSessions(next);
      return next;
    });
  }, []);

  const clearSessions = useCallback(async () => {
    setSessions([]);
    await Storage.saveSessions([]);
  }, []);

  // --- Sequences ---

  const saveSequence = useCallback(async (sequence: SessionSequence) => {
    setSequences((prev) => {
      const idx = prev.findIndex((s) => s.id === sequence.id);
      const next = idx >= 0 ? prev.map((s) => (s.id === sequence.id ? sequence : s)) : [...prev, sequence];
      Storage.saveSequences(next);
      return next;
    });
  }, []);

  const deleteSequence = useCallback(async (id: string) => {
    setSequences((prev) => {
      const next = prev.filter((s) => s.id !== id);
      Storage.saveSequences(next);
      return next;
    });
  }, []);

  // --- Settings ---

  const saveSettingsCb = useCallback(async (next: SessionSettings) => {
    setSettings(next);
    await Storage.saveSettings(next);
  }, []);

  // --- Premium ---

  const unlockPremium = useCallback(async () => {
    setIsPremium(true);
    await Storage.savePremiumStatus(true);
  }, []);

  // --- Memoised value ---

  const value = useMemo<AppContextValue>(
    () => ({
      profiles,
      templateProfiles,
      allProfiles,
      saveProfile,
      deleteProfile,
      sessions,
      addSession: addSessionCb,
      clearSessions,
      sequences,
      saveSequence,
      deleteSequence,
      settings,
      saveSettings: saveSettingsCb,
      isPremium,
      unlockPremium,
      isLoading,
    }),
    [
      profiles,
      templateProfiles,
      allProfiles,
      saveProfile,
      deleteProfile,
      sessions,
      addSessionCb,
      clearSessions,
      sequences,
      saveSequence,
      deleteSequence,
      settings,
      saveSettingsCb,
      isPremium,
      unlockPremium,
      isLoading,
    ],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

export function useAppContext(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) {
    throw new Error('useAppContext must be used within an <AppProvider>');
  }
  return ctx;
}
