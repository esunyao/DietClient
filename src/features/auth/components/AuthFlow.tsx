import React, { useCallback, useRef, useState } from 'react';
import {
  Controller,
  type Control,
  type FieldPath,
  type FieldValues,
  type RegisterOptions,
} from 'react-hook-form';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Eye, EyeOff } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ScreenTransition } from '../../../shared/animation/ScreenTransition';
import { AppButton, inputStyle } from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import { type FlowChallenge } from '../api/authApi';
export function FormField<T extends FieldValues>({
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
              placeholderTextColor={colors.placeholder}
              secureTextEntry={secureTextEntry ? hidden : false}
              style={[inputStyle, styles.input]}
              value={value}
            />
            {secureTextEntry ? (
              <Pressable
                accessibilityLabel={hidden ? '显示密码' : '隐藏密码'}
                hitSlop={8}
                onPress={() => setHidden(item => !item)}
                style={styles.eye}
              >
                {hidden ? (
                  <Eye color={colors.muted} size={18} />
                ) : (
                  <EyeOff color={colors.muted} size={18} />
                )}
              </Pressable>
            ) : null}
          </View>
          {error ? <Text style={styles.fieldError}>{error.message}</Text> : null}
        </View>
      )}
    />
  );
}
export function AuthShell({ children }: { children: React.ReactNode }) {
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
export function challengeFieldName(challenge: FlowChallenge): string {
  if (challenge.component.includes('authenticator')) return 'code';
  const fields = Array.isArray(challenge.fields) ? challenge.fields : [];
  const first = fields.find(item => item && typeof item === 'object') as
    | {
        name?: string;
        field_key?: string;
        key?: string;
      }
    | undefined;
  return first?.name || first?.field_key || first?.key || 'response';
}
export function ChallengeCard({
  challenge,
  onSubmit,
}: {
  challenge: FlowChallenge;
  onSubmit: (value: string) => void;
}) {
  const [value, setValue] = useState('');
  const fieldName = challengeFieldName(challenge);
  return (
    <View style={styles.challengeCard}>
      <Text style={styles.challengeTitle}>继续完成安全验证</Text>
      <Text style={styles.challengeDescription}>
        {challenge.component.includes('authenticator')
          ? '请输入 Authentik 验证码。'
          : 'Authentik 需要补充一项信息。'}
      </Text>
      <TextInput
        accessibilityLabel="安全验证信息"
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType={challenge.component.includes('authenticator') ? 'numeric' : 'default'}
        onChangeText={setValue}
        placeholder={fieldName}
        placeholderTextColor={colors.placeholder}
        secureTextEntry={challenge.component.includes('password')}
        style={inputStyle}
        value={value}
      />
      <AppButton label="继续" disabled={!value.trim()} onPress={() => onSubmit(value.trim())} />
    </View>
  );
}
export function useChallengeResolver() {
  const [challenge, setChallenge] = useState<FlowChallenge | null>(null);
  const resolver = useRef<((value: Record<string, unknown>) => void) | null>(null);
  const waitForChallenge = useCallback(
    (next: FlowChallenge) =>
      new Promise<Record<string, unknown>>(resolve => {
        resolver.current = resolve;
        setChallenge(next);
      }),
    [],
  );
  const submitChallenge = useCallback(
    (value: string) => {
      const next = challenge;
      resolver.current?.({
        [next ? challengeFieldName(next) : 'response']: value,
      });
      resolver.current = null;
      setChallenge(null);
    },
    [challenge],
  );
  return {
    challenge,
    waitForChallenge,
    submitChallenge,
  };
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
  field: {
    marginBottom: spacing.md,
  },
  fieldLabel: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 7,
  },
  inputWrap: {
    position: 'relative',
  },
  inputError: {
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.red,
  },
  input: {
    paddingRight: 48,
  },
  eye: {
    position: 'absolute',
    right: 14,
    top: 15,
  },
  fieldError: {
    color: colors.redInk,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 5,
  },
  challengeCard: {
    gap: spacing.sm,
    padding: spacing.md,
    marginBottom: spacing.md,
    borderRadius: radii.md,
    backgroundColor: colors.blueSoft,
  },
  challengeTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontWeight: '800',
    fontSize: 13,
  },
  challengeDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 18,
  },
});
