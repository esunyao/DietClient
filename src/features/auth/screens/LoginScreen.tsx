import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ArrowRight, Sparkles } from 'lucide-react-native';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, LogoMark } from '../../../shared/components';
import { colors, fonts, radii, shadows, spacing } from '../../../shared/theme/tokens';
import type { AuthStackParamList } from '../../../navigation/types';
import { useSessionStore } from '../../../app/session/sessionStore';
import { AuthentikFlowError, type LoginPayload } from '../api/authApi';
import { AuthShell, ChallengeCard, FormField, useChallengeResolver } from '../components/AuthFlow';
type LoginProps = NativeStackScreenProps<AuthStackParamList, 'Login'>;
export function LoginScreen({ navigation, route }: LoginProps) {
  const signIn = useSessionStore(state => state.signIn);
  const { control, handleSubmit, setValue } = useForm<LoginPayload>({
    defaultValues: {
      username: '',
      password: '',
    },
  });
  const { challenge, waitForChallenge, submitChallenge } = useChallengeResolver();
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  useEffect(() => {
    if (route.params?.registeredUsername) setValue('username', route.params.registeredUsername);
  }, [route.params?.registeredUsername, setValue]);
  const submit = handleSubmit(async values => {
    setSubmitting(true);
    setSubmitError(null);
    try {
      await signIn({
        ...values,
        onChallenge: waitForChallenge,
      });
    } catch (error) {
      const message = getErrorMessage(error);
      const isCredentialError =
        error instanceof AuthentikFlowError &&
        Boolean(error.responseErrors) &&
        (error.component === 'ak-stage-identification' || error.component === 'ak-stage-password');
      setSubmitError(
        isCredentialError ? '用户名或密码错误，账号也可能尚未完成邮箱验证。' : message,
      );
    } finally {
      setSubmitting(false);
    }
  });
  return (
    <AuthShell>
      <View style={styles.brandBlock}>
        <LogoMark />
        <Text style={styles.brandName}>NutriAI</Text>
        <Text style={styles.brandSubtitle}>把每一餐变成可理解的健康选择</Text>
      </View>
      <View style={styles.authCard}>
        <View style={styles.cardHeading}>
          <View style={styles.headingIcon}>
            <Sparkles color={colors.blue} size={17} />
          </View>
          <View>
            <Text style={styles.cardTitle}>欢迎回来</Text>
            <Text style={styles.cardDescription}>登录后查看你的营养轨迹</Text>
          </View>
        </View>
        <FormField
          control={control}
          name="username"
          label="用户名或邮箱"
          placeholder="输入用户名或邮箱"
          rules={{
            required: '请输入用户名或邮箱',
          }}
        />
        <FormField
          control={control}
          name="password"
          label="密码"
          placeholder="输入密码"
          secureTextEntry
          rules={{
            required: '请输入密码',
          }}
        />
        {route.params?.emailVerified ? (
          <Text style={styles.successMessage}>邮箱验证成功，请登录。</Text>
        ) : null}
        {challenge ? <ChallengeCard challenge={challenge} onSubmit={submitChallenge} /> : null}
        {submitError ? <Text style={styles.submitError}>{submitError}</Text> : null}
        <AppButton
          label="登录并查看健康档案"
          loading={submitting}
          disabled={Boolean(challenge)}
          onPress={submit}
        />
        <Pressable
          onPress={() =>
            navigation.navigate('VerifyEmail', {
              email: '',
            })
          }
          style={styles.secondaryAction}
        >
          <Text style={styles.switchAction}>邮箱尚未验证？重发验证邮件</Text>
        </Pressable>
        <Pressable onPress={() => navigation.navigate('Register')} style={styles.switchRow}>
          <Text style={styles.switchText}>还没有账号？</Text>
          <Text style={styles.switchAction}>
            创建账号 <ArrowRight color={colors.blue} size={14} />
          </Text>
        </Pressable>
      </View>
      <Text style={styles.disclaimer}>NutriAI 提供健康管理参考，不替代专业医疗建议。</Text>
    </AuthShell>
  );
}
const styles = StyleSheet.create({
  brandBlock: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  brandName: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 29,
    fontWeight: '800',
    letterSpacing: -0.8,
    marginTop: spacing.md,
  },
  brandSubtitle: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    marginTop: 5,
  },
  authCard: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    padding: spacing.xl,
    borderWidth: 1,
    borderColor: colors.line,
    boxShadow: shadows.card,
  },
  cardHeading: {
    flexDirection: 'row',
    gap: spacing.sm,
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  headingIcon: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  cardTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 20,
    fontWeight: '800',
    letterSpacing: -0.3,
  },
  cardDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    marginTop: 2,
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
  switchRow: {
    alignSelf: 'center',
    flexDirection: 'row',
    gap: 4,
    marginTop: spacing.lg,
    padding: 4,
  },
  switchText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
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
  disclaimer: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    lineHeight: 17,
    textAlign: 'center',
    marginTop: spacing.xl,
    paddingHorizontal: spacing.md,
  },
});
