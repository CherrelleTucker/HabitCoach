import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';
import { colors, spacing, fontSize } from '../services/theme';

interface Props {
  onClose: () => void;
}

// ---------- Section component ----------

function PolicySection({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <Text style={styles.sectionBody}>{body}</Text>
    </View>
  );
}

// ---------- Main component ----------

export default function PrivacyPolicyScreen({ onClose }: Props) {
  return (
    <View style={styles.container}>
      {/* Header bar */}
      <View style={styles.headerBar}>
        <Pressable onPress={onClose} style={styles.closeButton}>
          <Text style={styles.closeButtonText}>Close</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <Text style={styles.title}>Privacy Policy</Text>
        <Text style={styles.lastUpdated}>Last updated: March 2026</Text>

        <PolicySection
          title="Information Collection"
          body="HabitCoach does not collect, transmit, or store any personal data. The app functions entirely on your device without requiring an account or login."
        />

        <PolicySection
          title="Data Storage"
          body="All data, including your presets, session history, and settings, is stored locally on your device. No data is sent to external servers."
        />

        <PolicySection
          title="Third-Party Services"
          body="HabitCoach does not integrate with or send data to any third-party analytics, advertising, or tracking services."
        />

        <PolicySection
          title="Children's Privacy"
          body="HabitCoach is not directed at children under the age of 13. We do not knowingly collect any information from children."
        />

        <PolicySection
          title="Changes to This Policy"
          body="We may update this privacy policy from time to time. Any changes will be reflected on this page with an updated revision date."
        />

        <PolicySection
          title="Contact"
          body="If you have questions about this privacy policy, please contact us at com.ctuckersolutions@gmail.com."
        />
      </ScrollView>
    </View>
  );
}

// ---------- Styles ----------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  headerBar: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
  },
  closeButton: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
  },
  closeButtonText: {
    fontSize: fontSize.lg,
    color: colors.accent,
    fontWeight: '600',
  },
  scrollContent: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.xxl,
  },
  title: {
    fontSize: fontSize.xxl,
    fontWeight: 'bold',
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  lastUpdated: {
    fontSize: fontSize.sm,
    color: colors.secondaryText,
    marginBottom: spacing.lg,
  },
  section: {
    marginBottom: spacing.lg,
  },
  sectionTitle: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  sectionBody: {
    fontSize: fontSize.md,
    color: colors.secondaryText,
    lineHeight: 22,
  },
});
