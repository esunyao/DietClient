import React, { useEffect, useState } from 'react';
import { Controller, useForm, type Control, type FieldPath, type FieldValues, type RegisterOptions } from 'react-hook-form';
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ArrowRight, Eye, EyeOff, Sparkles } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, LogoMark, inputStyle } from '../../../shared/components/ui';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { LoginPayload, RegisterPayload } from '../../../shared/types/api';
import type { AuthStackParamList } from '../../../navigation/types';
import { useSessionStore } from '../store/sessionStore';

type LoginProps = NativeStackScreenProps<AuthStackParamList, 'Login'>;
type RegisterProps = NativeStackScreenProps<AuthStackParamList, 'Register'>;

function FormField<T extends FieldValues>({
  control,
  name,
  label,
  placeholder,
  rules,
  secureTextEntry,
  keyboardType,
  autoCapitalize = 'none',
}: {
  control: Control<T>;
  name: FieldPath<T>;
  label: string;
  placeholder: string;
  rules?: RegisterOptions<T, FieldPath<T>>;
  secureTextEntry?: boolean;
  keyboardType?: 'default' | 'email-address';
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
}) {
  const [hidden, setHidden] = useState(Boolean(secureTextEntry));

  return (
    <Controller
      control={control}
      name={name}
      rules={rules}
      render={({ field: { onBlur, onChange, value }, fieldState: { error } }) => (
        <View style={styles.field}>
          <Text style={styles.fieldLabel}>{label}</Text>
          <View style={[styles.inputWrap, error && styles.inputError]}>
            <TextInput
              accessibilityLabel={label}
              autoCapitalize={autoCapitalize}
              autoCorrect={false}
              keyboardType={keyboardType}
              onBlur={onBlur}
              onChangeText={onChange}
              placeholder={placeholder}
              placeholderTextColor="#95A4B7"
              secureTextEntry={secureTextEntry ? hidden : false}
              style={[inputStyle, styles.input]}
              value={value}
            />
            {secureTextEntry ? (
              <Pressable accessibilityLabel={hidden ? '显示密码' : '隐藏密码'} hitSlop={8} onPress={() => setHidden(item => !item)} style={styles.eye}>
                {hidden ? <Eye color={colors.muted} size={18} /> : <EyeOff color={colors.muted} size={18} />}
              </Pressable>
            ) : null}
          </View>
          {error ? <Text style={styles.fieldError}>{error.message}</Text> : null}
        </View>
      )}
    />
  );
}

function AuthShell({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaView style={styles.safeArea}>
      <KeyboardAvoidingView behavior={Platform.select({ ios: 'padding', default: undefined })} style={styles.keyboard}>
        <View style={styles.orbOne} />
        <View style={styles.orbTwo} />
        <View style={styles.content}>{children}</View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

export function LoginScreen({ navigation, route }: LoginProps) {
  const signIn = useSessionStore(state => state.signIn);
  const { control, handleSubmit, setValue } = useForm<LoginPayload>({ defaultValues: { username: '', password: '' } });
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  useEffect(() => {
    if (route.params?.registeredUsername) {
      setValue('username', route.params.registeredUsername);
    }
  }, [route.params?.registeredUsername, setValue]);

  const submit = handleSubmit(async values => {
    setSubmitting(true);
    setSubmitError(null);
    try {
      await signIn(values);
    } catch (error) {
      setSubmitError(getErrorMessage(error));
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
          <View style={styles.headingIcon}><Sparkles color={colors.blue} size={17} /></View>
          <View>
            <Text style={styles.cardTitle}>欢迎回来</Text>
            <Text style={styles.cardDescription}>登录后查看你的营养轨迹</Text>
          </View>
        </View>

        <FormField control={control} name="username" label="用户名" placeholder="输入用户名" rules={{ required: '请输入用户名' }} />
        <FormField control={control} name="password" label="密码" placeholder="输入密码" secureTextEntry rules={{ required: '请输入密码' }} />
        {submitError ? <Text style={styles.submitError}>{submitError}</Text> : null}
        <AppButton label="登录并查看健康档案" loading={submitting} onPress={submit} />

        <Pressable onPress={() => navigation.navigate('Register')} style={styles.switchRow}>
          <Text style={styles.switchText}>还没有账号？</Text>
          <Text style={styles.switchAction}>创建账号 <ArrowRight color={colors.blue} size={14} /></Text>
        </Pressable>
      </View>

      <Text style={styles.disclaimer}>NutriAI 提供健康管理参考，不替代专业医疗建议。</Text>
    </AuthShell>
  );
}

export function RegisterScreen({ navigation }: RegisterProps) {
  const register = useSessionStore(state => state.register);
  const { control, handleSubmit } = useForm<RegisterPayload>({
    defaultValues: { username: '', email: '', password: '', nickname: '' },
  });
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const submit = handleSubmit(async values => {
    setSubmitting(true);
    setSubmitError(null);
    try {
      await register(values);
      navigation.replace('Login', { registeredUsername: values.username });
    } catch (error) {
      setSubmitError(getErrorMessage(error));
    } finally {
      setSubmitting(false);
    }
  });

  return (
    <AuthShell>
      <Pressable accessibilityLabel="返回登录" onPress={() => navigation.goBack()} style={styles.backText}>
        <Text style={styles.backTextLabel}>← 返回登录</Text>
      </Pressable>
      <View style={styles.registerBrand}>
        <LogoMark size={50} />
        <Text style={styles.registerTitle}>建立你的健康档案</Text>
        <Text style={styles.registerDescription}>填写基础账户信息，健康画像可在登录后完善。</Text>
      </View>

      <View style={[styles.authCard, styles.registerCard]}>
        <FormField control={control} name="username" label="用户名" placeholder="2–50 个字符" rules={{ required: '请输入用户名', minLength: { value: 2, message: '用户名至少 2 个字符' }, maxLength: { value: 50, message: '用户名最多 50 个字符' } }} />
        <FormField control={control} name="email" label="邮箱" placeholder="name@example.com" keyboardType="email-address" rules={{ required: '请输入邮箱', pattern: { value: /^\S+@\S+\.\S+$/, message: '请输入正确的邮箱地址' } }} />
        <FormField control={control} name="nickname" label="昵称（选填）" placeholder="不填则使用用户名" autoCapitalize="words" />
        <FormField control={control} name="password" label="密码" placeholder="至少 6 个字符" secureTextEntry rules={{ required: '请设置密码', minLength: { value: 6, message: '密码至少 6 个字符' }, maxLength: { value: 100, message: '密码最多 100 个字符' } }} />
        {submitError ? <Text style={styles.submitError}>{submitError}</Text> : null}
        <AppButton label="创建账号" loading={submitting} onPress={submit} />
      </View>
    </AuthShell>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: colors.canvas },
  keyboard: { flex: 1, justifyContent: 'center' },
  content: { paddingHorizontal: spacing.xl, zIndex: 1 },
  orbOne: { position: 'absolute', top: 38, right: -55, width: 170, height: 170, borderRadius: 85, backgroundColor: '#D7F3E2', opacity: 0.72 },
  orbTwo: { position: 'absolute', bottom: -48, left: -60, width: 200, height: 200, borderRadius: 100, backgroundColor: '#DDEEFF', opacity: 0.82 },
  brandBlock: { alignItems: 'center', marginBottom: spacing.xl },
  brandName: { color: colors.ink, fontFamily: fonts.display, fontSize: 29, fontWeight: '800', letterSpacing: -0.8, marginTop: spacing.md },
  brandSubtitle: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, marginTop: 5 },
  authCard: { backgroundColor: 'rgba(255,255,255,0.94)', borderRadius: radii.lg, padding: spacing.xl, borderWidth: 1, borderColor: '#FFFFFF', boxShadow: '0 12px 24px rgba(76, 108, 138, 0.14)' },
  cardHeading: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center', marginBottom: spacing.xl },
  headingIcon: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  cardTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 20, fontWeight: '800', letterSpacing: -0.3 },
  cardDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 2 },
  field: { marginBottom: spacing.md },
  fieldLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700', marginBottom: 7 },
  inputWrap: { position: 'relative' },
  inputError: { borderRadius: radii.md, borderWidth: 1, borderColor: colors.red },
  input: { paddingRight: 48 },
  eye: { position: 'absolute', right: 14, top: 15 },
  fieldError: { color: '#C93025', fontFamily: fonts.body, fontSize: 11, marginTop: 5 },
  submitError: { color: '#C93025', backgroundColor: colors.redSoft, borderRadius: radii.sm, padding: spacing.sm, fontFamily: fonts.body, fontSize: 12, lineHeight: 18, marginBottom: spacing.md },
  switchRow: { alignSelf: 'center', flexDirection: 'row', gap: 4, marginTop: spacing.lg, padding: 4 },
  switchText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13 },
  switchAction: { color: colors.blue, fontFamily: fonts.body, fontSize: 13, fontWeight: '800' },
  disclaimer: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, lineHeight: 17, textAlign: 'center', marginTop: spacing.xl, paddingHorizontal: spacing.md },
  backText: { alignSelf: 'flex-start', paddingVertical: spacing.md },
  backTextLabel: { color: colors.blue, fontFamily: fonts.body, fontWeight: '700', fontSize: 13 },
  registerBrand: { alignItems: 'center', marginBottom: spacing.lg },
  registerTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 24, fontWeight: '800', letterSpacing: -0.5, marginTop: spacing.md },
  registerDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, textAlign: 'center', marginTop: 5 },
  registerCard: { paddingVertical: spacing.lg },
});
