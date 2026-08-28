import { useEffect, useState } from 'react';
import { Controller, useForm, useWatch, type Control, type RegisterOptions } from 'react-hook-form';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import {
  AppButton,
  AppScreen,
  EmptyState,
  GlassCard,
  ScreenHeader,
  SectionTitle,
  inputStyle,
  useToast,
} from '../../../shared/components';
import {
  DateWheelField,
  HealthSelectField,
  NumericWheelField,
  type HealthPickerOption,
} from '../../../shared/components';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { ActivityLevel, Gender, UserProfileUpdatePayload } from '../api/profileTypes';
import { useSessionStore } from '../../../app/session/sessionStore';
import { userApi } from '../api/userApi';
type EditProps = NativeStackScreenProps<ProfileStackParamList, 'EditProfile'>;
const activityLabels: Record<ActivityLevel, string> = {
  sedentary: '久坐',
  light: '轻度活动',
  moderate: '中度活动',
  active: '活跃',
  very_active: '高强度活动',
};
type EditForm = {
  birthDate: string;
  gender: Gender | '';
  heightCm: string;
  activityLevel: ActivityLevel | '';
  dailyWaterTargetMl: string;
};
function ProfileField({
  control,
  name,
  label,
  placeholder,
  keyboardType = 'default',
  date = false,
  rules,
  minimumDate,
  maximumDate,
}: {
  control: Control<EditForm>;
  name: keyof EditForm;
  label: string;
  placeholder: string;
  keyboardType?: 'default' | 'numeric';
  date?: boolean;
  rules?: RegisterOptions<EditForm, keyof EditForm>;
  minimumDate?: Date;
  maximumDate?: Date;
}) {
  return (
    <Controller
      control={control}
      name={name}
      rules={rules}
      render={({ field: { onBlur, onChange, value }, fieldState: { error } }) =>
        date ? (
          <DateWheelField
            label={label}
            minimumDate={minimumDate}
            maximumDate={maximumDate}
            optional
            value={value}
            onChange={nextValue => {
              onChange(nextValue);
              onBlur();
            }}
          />
        ) : (
          <View style={styles.formField}>
            <Text style={styles.formLabel}>{label}</Text>
            <TextInput
              onBlur={onBlur}
              onChangeText={onChange}
              placeholder={placeholder}
              placeholderTextColor="#94A3B8"
              keyboardType={keyboardType}
              style={[inputStyle, error && styles.formInputError]}
              value={value}
            />
            {error ? <Text style={styles.formError}>{error.message}</Text> : null}
          </View>
        )
      }
    />
  );
}
function ProfileNumericWheel({
  control,
  name,
  label,
  minimum,
  maximum,
  step,
  unit,
}: {
  control: Control<EditForm>;
  name: 'heightCm' | 'dailyWaterTargetMl';
  label: string;
  minimum: number;
  maximum: number;
  step: number;
  unit: string;
}) {
  return (
    <Controller
      control={control}
      name={name}
      render={({ field: { onBlur, onChange, value } }) => (
        <NumericWheelField
          label={label}
          maximum={maximum}
          minimum={minimum}
          onChange={nextValue => {
            onChange(nextValue);
            onBlur();
          }}
          step={step}
          unit={unit}
          value={value}
        />
      )}
    />
  );
}
function ChoiceGroup<T extends string>({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: T | '';
  onChange: (value: T) => void;
  options: Array<{
    value: T;
    label: string;
    description?: string;
  }>;
}) {
  return (
    <HealthSelectField
      label={label}
      onChange={next => onChange(next as T)}
      options={options as HealthPickerOption[]}
      value={value}
    />
  );
}
export function EditProfileScreen({ navigation, route }: EditProps) {
  const profile = useSessionStore(state => state.profile);
  const setProfile = useSessionStore(state => state.setProfile);
  const completeProfileOnboarding = useSessionStore(state => state.completeProfileOnboarding);
  const { show } = useToast();
  const { control, handleSubmit, reset, setValue } = useForm<EditForm>({
    defaultValues: {
      birthDate: '',
      gender: '',
      heightCm: '',
      activityLevel: '',
      dailyWaterTargetMl: '',
    },
  });
  // 定向订阅字段，避免 watch() 全表单订阅导致任意输入都重渲染整个表单。
  const gender = useWatch({
    control,
    name: 'gender',
  });
  const activityLevel = useWatch({
    control,
    name: 'activityLevel',
  });
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  useEffect(() => {
    if (profile)
      reset({
        birthDate: profile.birthDate || '',
        gender: profile.gender || '',
        heightCm: profile.heightCm?.toString() || '',
        activityLevel: profile.activityLevel || '',
        dailyWaterTargetMl: profile.dailyWaterTargetMl?.toString() || '',
      });
  }, [profile, reset]);
  const save = handleSubmit(async values => {
    setSaving(true);
    setSaveError(null);
    const payload: UserProfileUpdatePayload = {
      birthDate: values.birthDate.trim() || null,
      gender: values.gender || null,
      heightCm: values.heightCm.trim() ? Number(values.heightCm) : null,
      activityLevel: values.activityLevel || null,
      dailyWaterTargetMl: values.dailyWaterTargetMl.trim()
        ? Number(values.dailyWaterTargetMl)
        : null,
    };
    try {
      const nextProfile = await userApi.updateProfile(payload);
      setProfile(nextProfile);
      show('基础档案已保存', 'success');
      if (route.params?.onboarding) {
        await completeProfileOnboarding();
        // 首次基础资料保存后结束引导并回到“我的”根页，恢复底部导航。
        // 健康记录仍可从个人页的“管理”入口随时补充，避免新用户停留在
        // 没有底栏的二级管理页。
        navigation.reset({
          index: 0,
          routes: [
            {
              name: 'ProfileMain',
            },
          ],
        });
      } else {
        navigation.goBack();
      }
    } catch (error) {
      setSaveError(getErrorMessage(error));
    } finally {
      setSaving(false);
    }
  });
  if (!profile)
    return (
      <AppScreen header={<ScreenHeader title="编辑档案" onBack={() => navigation.goBack()} />}>
        <EmptyState title="没有可编辑的档案" description="请先返回上一页刷新。" />
      </AppScreen>
    );
  return (
    <AppScreen
      header={
        <ScreenHeader
          title="编辑基础档案"
          subtitle="填写基础数据，生成更贴合你的健康建议"
          onBack={() => navigation.goBack()}
        />
      }
    >
      <GlassCard>
        <SectionTitle title="基础信息" />
        <View style={styles.formSpace}>
          <ProfileField
            control={control}
            name="birthDate"
            label="出生日期"
            placeholder="YYYY-MM-DD"
            date
            minimumDate={new Date(new Date().getFullYear() - 120, 0, 1)}
            maximumDate={new Date(new Date().getFullYear() - 10, 11, 31)}
            rules={{
              pattern: {
                value: /^\d{4}-\d{2}-\d{2}$/,
                message: '请输入 YYYY-MM-DD',
              },
            }}
          />
          <ChoiceGroup
            label="性别"
            value={gender}
            onChange={value => setValue('gender', value)}
            options={[
              {
                value: 'male',
                label: '男',
                description: '用于基础健康参考',
              },
              {
                value: 'female',
                label: '女',
                description: '用于基础健康参考',
              },
              {
                value: 'other',
                label: '其他',
                description: '使用中性健康建议',
              },
              {
                value: 'unknown',
                label: '暂不说明',
                description: '之后可随时补充',
              },
            ]}
          />
          <ProfileNumericWheel
            control={control}
            label="身高"
            maximum={300}
            minimum={50}
            name="heightCm"
            step={0.1}
            unit="cm"
          />
          <ChoiceGroup
            label="活动水平"
            value={activityLevel}
            onChange={value => setValue('activityLevel', value)}
            options={Object.entries(activityLabels).map(([value, label]) => ({
              value: value as ActivityLevel,
              label,
              description:
                value === 'sedentary'
                  ? '日常久坐，运动较少'
                  : value === 'light'
                  ? '偶尔步行或轻运动'
                  : value === 'moderate'
                  ? '规律中等强度活动'
                  : value === 'active'
                  ? '每周高频运动'
                  : '高强度或体力活动较多',
            }))}
          />
          <ProfileNumericWheel
            control={control}
            label="每日饮水目标"
            maximum={10000}
            minimum={0}
            name="dailyWaterTargetMl"
            step={100}
            unit="ml"
          />
        </View>
      </GlassCard>
      {saveError ? <Text style={styles.saveError}>{saveError}</Text> : null}
      <AppButton label="保存基础档案" loading={saving} onPress={save} />
    </AppScreen>
  );
}
const styles = StyleSheet.create({
  formSpace: {
    marginTop: spacing.lg,
    gap: spacing.md,
  },
  formField: {
    marginBottom: spacing.md,
  },
  formLabel: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 7,
  },
  formInputError: {
    borderColor: colors.red,
  },
  formError: {
    color: '#C93025',
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 5,
  },
  saveError: {
    color: '#C93025',
    backgroundColor: colors.redSoft,
    borderRadius: radii.sm,
    fontFamily: fonts.body,
    fontSize: 12,
    lineHeight: 18,
    padding: spacing.sm,
  },
});
