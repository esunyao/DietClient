import React from 'react';
import { KeyboardAvoidingView, Platform, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { CircleCheck } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ScreenTransition } from '../../../shared/animation/ScreenTransition';
import { AppButton } from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { AuthStackParamList } from '../../../navigation/types';
type EmailVerifiedProps = NativeStackScreenProps<AuthStackParamList, 'EmailVerified'>;
function AuthShell({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaView style={styles.safeArea}>
      <ScreenTransition style={styles.screenTransition}>
        <KeyboardAvoidingView
          behavior={Platform.select({
            ios: 'padding',
            default: undefined,
          })}
          style={styles.keyboard}
        >
          <View style={styles.content}>{children}</View>
        </KeyboardAvoidingView>
      </ScreenTransition>
    </SafeAreaView>
  );
}
export function EmailVerifiedScreen({ navigation }: EmailVerifiedProps) {
  return (
    <AuthShell>
      <View style={styles.statusCard}>
        <View style={[styles.statusIcon, styles.verifiedIcon]}>
          <CircleCheck color={colors.green} size={38} />
        </View>
        <Text style={styles.statusTitle}>邮箱验证成功</Text>
        <Text style={styles.statusDescription}>
          你的账号已经激活，现在可以登录并继续完善健康资料。
        </Text>
        <AppButton
          label="返回登录"
          onPress={() =>
            navigation.replace('Login', {
              emailVerified: true,
            })
          }
        />
      </View>
    </AuthShell>
  );
}
const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.canvas,
  },
  screenTransition: {
    flex: 1,
  },
  keyboard: {
    flex: 1,
    justifyContent: 'center',
  },
  content: {
    paddingHorizontal: spacing.xl,
    zIndex: 1,
  },
  statusCard: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    padding: spacing.xl,
    gap: spacing.md,
    alignItems: 'stretch',
  },
  statusIcon: {
    alignSelf: 'center',
    width: 68,
    height: 68,
    borderRadius: 34,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  verifiedIcon: {
    backgroundColor: colors.greenSoft,
  },
  statusTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 24,
    fontWeight: '800',
    textAlign: 'center',
  },
  statusDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    lineHeight: 20,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
});
