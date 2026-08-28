import { useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, LogoMark } from '../../../shared/components';
import { colors, fonts, radii, shadows, spacing } from '../../../shared/theme/tokens';
import type { AuthStackParamList } from '../../../navigation/types';
import { useSessionStore } from '../../../app/session/sessionStore';
import {
  getRegistrationFieldErrors,
  resolveRegistrationNickname,
  type RegisterPayload,
} from '../api/authApi';
import { AuthShell, ChallengeCard, FormField, useChallengeResolver } from '../components/AuthFlow';
type RegisterProps = NativeStackScreenProps<AuthStackParamList, 'Register'>;
type RegisterForm = RegisterPayload & {
  confirmPassword: string;
};
export function RegisterScreen({ navigation }: RegisterProps) {
  const register = useSessionStore(state => state.register);
  const { clearErrors, control, handleSubmit, setError } = useForm<RegisterForm>({
    defaultValues: {
      username: '',
      email: '',
      password: '',
      confirmPassword: '',
      displayName: '',
    },
  });
  const { challenge, waitForChallenge, submitChallenge } = useChallengeResolver();
  const submitLock = useRef(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const submit = handleSubmit(async values => {
    if (submitLock.current) return;
    if (values.password !== values.confirmPassword) {
      setError('confirmPassword', {
        type: 'validate',
        message: '两次输入的密码不一致',
      });
      return;
    }
    submitLock.current = true;
    setSubmitting(true);
    setSubmitError(null);
    clearErrors();
    try {
      const result = await register({
        username: values.username,
        email: values.email,
        password: values.password,
        displayName: resolveRegistrationNickname(values.username, values.displayName),
        onChallenge: waitForChallenge,
      });
      navigation.replace('VerifyEmail', {
        email: result.email,
        username: result.username,
      });
    } catch (error) {
      const fieldErrors = getRegistrationFieldErrors(error);
      Object.entries(fieldErrors).forEach(([name, message]) => {
        if (message)
          setError(name as keyof RegisterForm, {
            type: 'server',
            message,
          });
      });
      if (Object.keys(fieldErrors).length === 0) setSubmitError(getErrorMessage(error));
    } finally {
      submitLock.current = false;
      setSubmitting(false);
    }
  });
  return (
    <AuthShell>
      <ScrollView
        contentContainerStyle={styles.registerScroll}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Pressable
          accessibilityLabel="返回登录"
          onPress={() => navigation.goBack()}
          style={styles.backText}
        >
          <Text style={styles.backTextLabel}>← 返回登录</Text>
        </Pressable>
        <View style={styles.registerBrand}>
          <LogoMark size={50} />
          <Text style={styles.registerTitle}>从今天开始记录健康</Text>
          <Text style={styles.registerDescription}>先创建账号，验证并登录后即可完成健康资料。</Text>
        </View>
        <View style={[styles.authCard, styles.registerCard]}>
          <Text style={styles.registerCardTitle}>创建账号</Text>
          <Text style={styles.registerCardCaption}>这些信息用于登录和找回账号。</Text>
          <FormField
            control={control}
            name="username"
            label="用户名"
            placeholder="2–50 个字符"
            rules={{
              required: '请输入用户名',
              minLength: {
                value: 2,
                message: '用户名至少 2 个字符',
              },
              maxLength: {
                value: 50,
                message: '用户名最多 50 个字符',
              },
            }}
          />
          <FormField
            control={control}
            name="email"
            label="邮箱"
            placeholder="name@example.com"
            keyboardType="email-address"
            rules={{
              required: '请输入邮箱',
              pattern: {
                value: /^\S+@\S+\.\S+$/,
                message: '请输入正确的邮箱地址',
              },
            }}
          />
          <FormField
            control={control}
            name="displayName"
            label="显示名（选填）"
            placeholder="不填则使用用户名"
            autoCapitalize="words"
          />
          <FormField
            control={control}
            name="password"
            label="设置密码"
            placeholder="至少 6 个字符"
            secureTextEntry
            rules={{
              required: '请设置密码',
              minLength: {
                value: 6,
                message: '密码至少 6 个字符',
              },
              maxLength: {
                value: 100,
                message: '密码最多 100 个字符',
              },
            }}
          />
          <FormField
            control={control}
            name="confirmPassword"
            label="确认密码"
            placeholder="再次输入密码"
            secureTextEntry
            rules={{
              required: '请再次输入密码',
            }}
          />
        </View>
        <View style={[styles.authCard, styles.healthGuideCard]}>
          <Text style={styles.registerCardTitle}>接下来完善健康资料</Text>
          <Text style={styles.healthGuideText}>
            完成邮箱验证并首次登录后，我们会引导你填写基础档案、身体测量、健康目标与饮食提醒。所有内容都可以之后再编辑。
          </Text>
        </View>
        {challenge ? <ChallengeCard challenge={challenge} onSubmit={submitChallenge} /> : null}
        {submitError ? <Text style={styles.submitError}>{submitError}</Text> : null}
        <AppButton
          label="创建账号并继续"
          loading={submitting}
          disabled={submitting || Boolean(challenge)}
          onPress={submit}
        />
      </ScrollView>
    </AuthShell>
  );
}
const styles = StyleSheet.create({
  authCard: {
    backgroundColor: colors.surface,
    borderRadius: radii.lg,
    padding: spacing.xl,
    borderWidth: 1,
    borderColor: colors.line,
    boxShadow: shadows.card,
  },
  registerCard: {
    paddingVertical: spacing.lg,
  },
  registerScroll: {
    gap: spacing.md,
    paddingBottom: spacing.xxl,
  },
  registerCardTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
  },
  registerCardCaption: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    marginBottom: spacing.lg,
    marginTop: 3,
  },
  healthGuideCard: {
    gap: spacing.sm,
    backgroundColor: colors.blueSoft,
  },
  healthGuideText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 19,
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
  backText: {
    alignSelf: 'flex-start',
    paddingVertical: spacing.md,
  },
  backTextLabel: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontWeight: '700',
    fontSize: 13,
  },
  registerBrand: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  registerTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 24,
    fontWeight: '800',
    letterSpacing: -0.5,
    marginTop: spacing.md,
  },
  registerDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    textAlign: 'center',
    marginTop: 5,
  },
});
