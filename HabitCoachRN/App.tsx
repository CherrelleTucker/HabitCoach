import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  Pressable,
  StatusBar,
  SafeAreaView,
  Platform,
  ActivityIndicator,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppProvider, useAppContext } from './src/services/AppContext';
import TimerScreen from './src/screens/TimerScreen';
import ProfileListScreen from './src/screens/ProfileListScreen';
import ProfileEditScreen from './src/screens/ProfileEditScreen';
import SequenceListScreen from './src/screens/SequenceListScreen';
import SequenceEditScreen from './src/screens/SequenceEditScreen';
import SequenceTimerScreen from './src/screens/SequenceTimerScreen';
import HistoryScreen from './src/screens/HistoryScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import OnboardingScreen from './src/screens/OnboardingScreen';
import UpgradeScreen from './src/screens/UpgradeScreen';
import PrivacyPolicyScreen from './src/screens/PrivacyPolicyScreen';
import { SessionProfile, SessionSequence, PremiumFeature } from './src/models/types';
import { colors, spacing, fontSize } from './src/services/theme';

const ONBOARDING_KEY = 'habitcoach_has_seen_onboarding';

type Screen = 'Timer' | 'Presets' | 'Sequences' | 'History' | 'Settings';

interface MenuItem {
  key: Screen;
  label: string;
  icon: string;
}

const MENU_ITEMS: MenuItem[] = [
  { key: 'Timer', label: 'Timer', icon: '\u23F1' },
  { key: 'Presets', label: 'Presets', icon: '\u2699' },
  { key: 'Sequences', label: 'Sequences', icon: '\u25B6' },
  { key: 'History', label: 'History', icon: '\uD83D\uDCCB' },
  { key: 'Settings', label: 'Settings', icon: '\u2630' },
];

// ---------------------------------------------------------------------------
// Inner app (has access to AppContext)
// ---------------------------------------------------------------------------

function AppInner() {
  const ctx = useAppContext();

  // -- onboarding -----------------------------------------------------------
  const [hasSeenOnboarding, setHasSeenOnboarding] = useState<boolean | null>(null);

  useEffect(() => {
    AsyncStorage.getItem(ONBOARDING_KEY).then((val) => {
      setHasSeenOnboarding(val === 'true');
    });
  }, []);

  const completeOnboarding = async () => {
    await AsyncStorage.setItem(ONBOARDING_KEY, 'true');
    setHasSeenOnboarding(true);
  };

  // -- navigation -----------------------------------------------------------
  const [activeScreen, setActiveScreen] = useState<Screen>('Timer');
  const [menuOpen, setMenuOpen] = useState(false);
  const [sessionActive, setSessionActive] = useState(false);

  // -- modal state ----------------------------------------------------------
  const [selectedProfile, setSelectedProfile] = useState<SessionProfile | undefined>();
  const [editingProfile, setEditingProfile] = useState<SessionProfile | undefined>();
  const [showProfileEdit, setShowProfileEdit] = useState(false);
  const [isCreatingProfile, setIsCreatingProfile] = useState(false);

  const [editingSequence, setEditingSequence] = useState<SessionSequence | undefined>();
  const [showSequenceEdit, setShowSequenceEdit] = useState(false);
  const [playingSequence, setPlayingSequence] = useState<SessionSequence | null>(null);

  const [showUpgrade, setShowUpgrade] = useState(false);
  const [upgradeHighlight, setUpgradeHighlight] = useState<PremiumFeature | undefined>();

  const [showPrivacyPolicy, setShowPrivacyPolicy] = useState(false);

  // -- loading / onboarding guards -----------------------------------------
  if (hasSeenOnboarding === null || ctx.isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={colors.accent} />
      </View>
    );
  }

  if (!hasSeenOnboarding) {
    return <OnboardingScreen onComplete={completeOnboarding} />;
  }

  // -- sequence timer (full-screen takeover) --------------------------------
  if (playingSequence) {
    return (
      <View style={styles.root}>
        <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
        <SafeAreaView style={styles.safeArea}>
          <SequenceTimerScreen
            sequence={playingSequence}
            onComplete={() => setPlayingSequence(null)}
          />
        </SafeAreaView>
      </View>
    );
  }

  // -- handlers -------------------------------------------------------------
  function handleMenuSelect(screen: Screen) {
    setActiveScreen(screen);
    setMenuOpen(false);
  }

  function handleEditProfile(profile: SessionProfile) {
    setEditingProfile(profile);
    setIsCreatingProfile(false);
    setShowProfileEdit(true);
  }

  function handleCreateProfile() {
    setEditingProfile(undefined);
    setIsCreatingProfile(true);
    setShowProfileEdit(true);
  }

  function handleSaveProfile(profile: SessionProfile) {
    ctx.saveProfile(profile);
    setShowProfileEdit(false);
    setEditingProfile(undefined);
  }

  function handleDeleteProfile(id: string) {
    ctx.deleteProfile(id);
    setShowProfileEdit(false);
    setEditingProfile(undefined);
  }

  function handleEditSequence(sequence: SessionSequence) {
    setEditingSequence(sequence);
    setShowSequenceEdit(true);
  }

  function handleCreateSequence() {
    setEditingSequence(undefined);
    setShowSequenceEdit(true);
  }

  function handleSaveSequence(sequence: SessionSequence) {
    ctx.saveSequence(sequence);
    setShowSequenceEdit(false);
    setEditingSequence(undefined);
  }

  function handlePlaySequence(sequence: SessionSequence) {
    setPlayingSequence(sequence);
  }

  function handleShowUpgrade(feature?: PremiumFeature) {
    setUpgradeHighlight(feature);
    setShowUpgrade(true);
  }

  function handleUnlockPremium() {
    ctx.unlockPremium();
    setShowUpgrade(false);
  }

  // -- render active screen -------------------------------------------------
  function renderActiveScreen() {
    switch (activeScreen) {
      case 'Presets':
        return (
          <ProfileListScreen
            onEditProfile={handleEditProfile}
            onCreateProfile={handleCreateProfile}
            onSelectProfile={(profile) => {
              setSelectedProfile(profile);
              setActiveScreen('Timer');
            }}
            onShowUpgrade={handleShowUpgrade}
          />
        );
      case 'Sequences':
        return (
          <SequenceListScreen
            onEditSequence={handleEditSequence}
            onCreateSequence={handleCreateSequence}
            onPlaySequence={handlePlaySequence}
            onShowUpgrade={handleShowUpgrade}
          />
        );
      case 'History':
        return <HistoryScreen />;
      case 'Settings':
        return (
          <SettingsScreen
            onShowPrivacyPolicy={() => setShowPrivacyPolicy(true)}
            onShowUpgrade={handleShowUpgrade}
          />
        );
      default:
        return null;
    }
  }

  return (
    <View style={styles.root}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      <SafeAreaView style={styles.safeArea}>
        {/* TimerScreen stays mounted, toggled via opacity */}
        <View
          style={[
            styles.screenContainer,
            { opacity: activeScreen === 'Timer' ? 1 : 0 },
            activeScreen !== 'Timer' && styles.hidden,
          ]}
          pointerEvents={activeScreen === 'Timer' ? 'auto' : 'none'}
        >
          <TimerScreen
            profile={selectedProfile}
            onSessionEnd={() => {
              setSelectedProfile(undefined);
              setSessionActive(false);
            }}
          />
        </View>

        {/* Other screens mount/unmount */}
        {activeScreen !== 'Timer' && (
          <View style={styles.screenContainer}>{renderActiveScreen()}</View>
        )}

        {/* Hamburger menu button - hidden during active session */}
        {!sessionActive && (
          <TouchableOpacity
            style={styles.menuButton}
            onPress={() => setMenuOpen(true)}
            activeOpacity={0.8}
            accessibilityLabel="Open navigation menu"
            accessibilityRole="button"
          >
            <Text style={styles.menuButtonIcon}>{'\u2630'}</Text>
          </TouchableOpacity>
        )}

        {/* Dropdown overlay menu */}
        <Modal
          visible={menuOpen}
          transparent
          animationType="fade"
          onRequestClose={() => setMenuOpen(false)}
        >
          <Pressable style={styles.backdrop} onPress={() => setMenuOpen(false)}>
            <View style={styles.menuCard}>
              {MENU_ITEMS.map((item) => (
                <TouchableOpacity
                  key={item.key}
                  style={styles.menuItem}
                  onPress={() => handleMenuSelect(item.key)}
                  activeOpacity={0.6}
                >
                  <Text style={styles.menuItemIcon}>{item.icon}</Text>
                  <Text
                    style={[
                      styles.menuItemLabel,
                      activeScreen === item.key && styles.menuItemLabelActive,
                    ]}
                  >
                    {item.label}
                  </Text>
                  {activeScreen === item.key && (
                    <Text style={styles.checkmark}>{'\u2713'}</Text>
                  )}
                </TouchableOpacity>
              ))}
            </View>
          </Pressable>
        </Modal>

        {/* ── Profile Edit Modal ── */}
        <Modal
          visible={showProfileEdit}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setShowProfileEdit(false)}
        >
          <SafeAreaView style={styles.modalSafeArea}>
            <ProfileEditScreen
              existing={editingProfile}
              isPremium={ctx.isPremium}
              onSave={handleSaveProfile}
              onClose={() => {
                setShowProfileEdit(false);
                setEditingProfile(undefined);
              }}
            />
          </SafeAreaView>
        </Modal>

        {/* ── Sequence Edit Modal ── */}
        <Modal
          visible={showSequenceEdit}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setShowSequenceEdit(false)}
        >
          <SafeAreaView style={styles.modalSafeArea}>
            <SequenceEditScreen
              existing={editingSequence}
              profiles={ctx.allProfiles}
              onSave={handleSaveSequence}
              onClose={() => {
                setShowSequenceEdit(false);
                setEditingSequence(undefined);
              }}
            />
          </SafeAreaView>
        </Modal>

        {/* ── Upgrade Modal ── */}
        <Modal
          visible={showUpgrade}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setShowUpgrade(false)}
        >
          <SafeAreaView style={styles.modalSafeArea}>
            <UpgradeScreen
              highlightedFeature={upgradeHighlight}
              onClose={() => setShowUpgrade(false)}
              onUnlock={handleUnlockPremium}
            />
          </SafeAreaView>
        </Modal>

        {/* ── Privacy Policy Modal ── */}
        <Modal
          visible={showPrivacyPolicy}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setShowPrivacyPolicy(false)}
        >
          <SafeAreaView style={styles.modalSafeArea}>
            <PrivacyPolicyScreen onClose={() => setShowPrivacyPolicy(false)} />
          </SafeAreaView>
        </Modal>
      </SafeAreaView>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Root component — wraps with AppProvider
// ---------------------------------------------------------------------------

export default function App() {
  return (
    <AppProvider>
      <AppInner />
    </AppProvider>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const MENU_TOP = Platform.OS === 'ios' ? 60 : 48;

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.background,
  },
  safeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  modalSafeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  loadingContainer: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
  },
  screenContainer: {
    ...StyleSheet.absoluteFillObject,
  },
  hidden: {
    position: 'absolute',
  },

  // Hamburger button
  menuButton: {
    position: 'absolute',
    top: MENU_TOP,
    left: spacing.md,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.25,
        shadowRadius: 4,
      },
      android: {
        elevation: 6,
      },
    }),
  },
  menuButtonIcon: {
    color: colors.onAccent,
    fontSize: 20,
    fontWeight: '600',
  },

  // Backdrop
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.3)',
  },

  // Floating menu card
  menuCard: {
    position: 'absolute',
    top: MENU_TOP + 48,
    left: spacing.md,
    width: 220,
    backgroundColor: colors.cardBackground,
    borderRadius: 14,
    paddingVertical: spacing.sm,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.2,
        shadowRadius: 12,
      },
      android: {
        elevation: 8,
      },
    }),
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: spacing.md,
  },
  menuItemIcon: {
    fontSize: 18,
    width: 28,
    textAlign: 'center',
  },
  menuItemLabel: {
    flex: 1,
    fontSize: fontSize.md,
    color: colors.primary,
    fontWeight: '400',
  },
  menuItemLabelActive: {
    fontWeight: '600',
    color: colors.accent,
  },
  checkmark: {
    fontSize: fontSize.md,
    color: colors.accent,
    fontWeight: '700',
    marginLeft: spacing.sm,
  },
});
