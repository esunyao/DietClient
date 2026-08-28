import React, { useEffect, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { Mail } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { getErrorMessage } from '../../../shared/api/client';
import { ScreenTransition } from '../../../shared/animation/ScreenTransition';
import { AppButton, inputStyle } from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { AuthStackParamList } from '../../../navigation/types';
import { useSessionStore } from '../../../app/session/sessionStore';
type VerifyEmailProps = NativeStackScreenProps<AuthStackParamList, 'VerifyEmail'>;
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
const RESEND_COOLDOWN_SECONDS = 60;
export function VerifyEmailScreen({ navigation, route }: VerifyEmailProps) {
  const resendVerificationEmail = useSessionStore(state => state.resendVerificationEmail);
  const [email, setEmail] = useState(route.params.email);
  const [secondsLeft, setSecondsLeft] = useState(route.params.email ? RESEND_COOLDOWN_SECONDS : 0);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState(
    route.params.email ? '验证邮件已发送，请检查收件箱和垃圾邮件。' : '',
  );
  const [submitError, setSubmitError] = useState<string | null>(null);
  useEffect(() => {
    if (secondsLeft <= 0) return undefined;
    const timer = setTimeout(() => setSecondsLeft(value => Math.max(0, value - 1)), 1_000);
    return () => clearTimeout(timer);
  }, [secondsLeft]);
  const resend = async () => {
    const normalizedEmail = email.trim();
    if (!/^\S+@\S+\.\S+$/.test(normalizedEmail)) {
      setSubmitError('请输入正确的邮箱地址');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    try {
      await resendVerificationEmail(normalizedEmail);
      setMessage('如果该邮箱存在且需要验证，我们已发送验证邮件。');
      setSecondsLeft(RESEND_COOLDOWN_SECONDS);
    } catch (error) {
      setSubmitError(getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };
  return (
    <AuthShell>
      <View style={styles.statusCard}>
        <View style={styles.statusIcon}>
          <Mail color={colors.blue} size={34} />
        </View>
        <Text style={styles.statusTitle}>验证你的邮箱</Text>
        <Text style={styles.statusDescription}>
          点击邮件中的验证链接后会自动返回 NutriAI。链接过期时，可以在这里重新发送。
        </Text>
        <TextInput
          accessibilityLabel="邮箱"
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="email-address"
          onChangeText={setEmail}
          placeholder="name@example.com"
          placeholderTextColor={colors.placeholder}
          style={inputStyle}
          value={email}
        />
        {message ? <Text style={styles.successMessage}>{message}</Text> : null}
        {submitError ? <Text style={styles.submitError}>{submitError}</Text> : null}
        <AppButton
          label={secondsLeft > 0 ? `${secondsLeft} 秒后可重新发送` : '重发验证邮件'}
          loading={submitting}
          disabled={submitting || secondsLeft > 0}
          onPress={resend}
        />
        <Pressable
          onPress={() =>
            navigation.replace('Login', {
              registeredUsername: route.params.username,
            })
          }
          style={styles.secondaryAction}
        >
          <Text style={styles.switchAction}>返回登录</Text>
        </Pressable>
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
  submitError: {
    color: colors.redInk,
    backgroundColor: colors.redSoft,
    borderRadius: radii.sm,
    padding: spacing.sm,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 18,
    marginBottom: spacing.md,
  },
  successMessage: {
    color: colors.greenInk,
    backgroundColor: colors.greenSoft,
    borderRadius: radii.sm,
    padding: spacing.sm,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 18,
    marginBottom: spacing.md,
  },
  switchAction: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '800',
  },
  secondaryAction: {
    alignSelf: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
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
