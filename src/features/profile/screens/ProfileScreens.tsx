import React, { memo, useCallback, useEffect, useState, useTransition } from 'react';
import {
  Controller,
  useForm,
  useWatch,
  type Control,
  type RegisterOptions,
} from 'react-hook-form';
import {
  Activity,
  Ban,
  Cake,
  ChevronRight,
  Droplets,
  FileText,
  HeartPulse,
  Pencil,
  RefreshCw,
  Ruler,
  Scale,
  ShieldAlert,
  Stethoscope,
  UserRound,
} from 'lucide-react-native';
import {
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';
import {
  BottomSheetBackdrop,
  BottomSheetModal,
  BottomSheetView,
  type BottomSheetBackdropProps,
} from '@gorhom/bottom-sheet';
import {
  launchCamera,
  launchImageLibrary,
  type Asset,
} from 'react-native-image-picker';

import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { PressableScale } from '../../../shared/animation/PressableScale';
import {
  AppButton,
  AppScreen,
  Avatar,
  EmptyState,
  GlassCard,
  ScreenHeader,
  SectionTitle,
  Tag,
  inputStyle,
  useToast,
} from '../../../shared/components';
import { DateWheelField, HealthSelectField, NumericWheelField, type HealthPickerOption } from '../../../shared/components';
import { useScrollChrome } from '../../../shared/scrollChrome/ScrollChromeProvider';
import { scheduleIdleTask } from '../../../shared/perf/scheduleIdleTask';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type {
  ActivityLevel,
  BodyMeasurement,
  Gender,
  UserProfileUpdatePayload,
} from '../../../shared/types/api';
import { useSessionStore } from '../../auth/store/sessionStore';
import { userApi } from '../api/userApi';
import {
  prepareAvatarFile,
  uploadAvatarBinary,
} from '../services/avatar';
import { getHealthRecords } from '../services/healthRecords';

type ProfileProps = NativeStackScreenProps<
  ProfileStackParamList,
  'ProfileMain'
>;
type EditProps = NativeStackScreenProps<ProfileStackParamList, 'EditProfile'>;

const genderLabels: Record<Gender, string> = {
  male: '男',
  female: '女',
  other: '其他',
  unknown: '未说明',
};
const activityLabels: Record<ActivityLevel, string> = {
  sedentary: '久坐',
  light: '轻度活动',
  moderate: '中度活动',
  active: '活跃',
  very_active: '高强度活动',
};

function displayValue(
  value: string | number | null | undefined,
  suffix = '',
): string {
  return value === null || value === undefined || value === ''
    ? '待完善'
    : `${value}${suffix}`;
}

// ProfileScreen 传给 InfoRow 的静态图标：提为模块常量，引用稳定后 InfoRow 的 memo 才真正生效，
// 避免每次父渲染都因新的 JSX 元素引用而重渲染（这是 trace 中 createTask/GC 热点的来源之一）。
const ICON_GENDER = <UserRound color={colors.muted} size={17} />;
const ICON_BIRTHDATE = <Cake color={colors.muted} size={17} />;
const ICON_HEIGHT = <Ruler color={colors.muted} size={17} />;
const ICON_ACTIVITY = <Activity color={colors.muted} size={17} />;
const ICON_WATER = <Droplets color={colors.muted} size={17} />;
const ICON_WEIGHT = <Scale color={colors.muted} size={17} />;
const ICON_HEART_RATE = <HeartPulse color={colors.muted} size={17} />;
const ICON_ALLERGY = <ShieldAlert color={colors.muted} size={17} />;
const ICON_CONDITION = <Stethoscope color={colors.muted} size={17} />;
const ICON_RESTRICTION = <Ban color={colors.muted} size={17} />;

const InfoRow = memo(function ({
  icon,
  label,
  value,
  accent,
  showDivider = true,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  accent?: 'green' | 'amber' | 'red';
  showDivider?: boolean;
}) {
  return (
    <View style={[styles.infoRow, !showDivider && styles.infoRowLast]}>
      <View style={styles.infoLead}>
        <View style={styles.infoIcon}>{icon}</View>
        <Text style={styles.infoLabel}>{label}</Text>
      </View>
      <View style={styles.infoValueSlot}>
        {accent ? (
          <Tag label={value} tone={accent} style={styles.infoValueTag} />
        ) : (
          <Text numberOfLines={2} style={styles.infoValue}>
            {value}
          </Text>
        )}
      </View>
    </View>
  );
});

const ProfileAction = memo(function ({
  icon,
  label,
  onPress,
}: {
  icon: React.ReactNode;
  label: string;
  onPress: () => void;
}) {
  return (
    <PressableScale
      accessibilityRole="button"
      onPress={onPress}
      style={styles.profileAction}
    >
      <View style={styles.profileActionIcon}>{icon}</View>
      <Text
        numberOfLines={1}
        style={styles.profileActionLabel}
        adjustsFontSizeToFit={true}
      >
        {label}
      </Text>
      <ChevronRight color={colors.muted} size={16} />
    </PressableScale>
  );
});

const AvatarEditor = memo(function ({ size = 60 }: { size?: number }) {
  const sheetRef = React.useRef<BottomSheetModal>(null);
  const { setTabHidden } = useScrollChrome();
  const user = useSessionStore(state => state.user);
  const avatarPreviewUrl = useSessionStore(state => state.avatarPreviewUrl);
  const setUser = useSessionStore(state => state.setUser);
  const setAvatarPreviewUrl = useSessionStore(
    state => state.setAvatarPreviewUrl,
  );
  const refreshUserData = useSessionStore(state => state.refreshUserData);
  const { show } = useToast();
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [sheetMounted, setSheetMounted] = useState(false);

  useEffect(() => {
    if (sheetMounted) sheetRef.current?.present();
  }, [sheetMounted]);

  const renderBackdrop = useCallback(
    (props: BottomSheetBackdropProps) => (
      <BottomSheetBackdrop
        {...props}
        appearsOnIndex={0}
        disappearsOnIndex={-1}
        opacity={0.28}
        pressBehavior="close"
      />
    ),
    [],
  );

  const upload = useCallback(
    async (asset?: Asset) => {
      if (!asset || !user) return;
      setUploading(true);
      setProgress(0);
      try {
        const file = await prepareAvatarFile(asset);
        const presign = await userApi.createAvatarUpload({
          fileName: file.fileName,
          contentType: file.contentType,
        });
        await uploadAvatarBinary(file, presign.uploadUrl, setProgress);
        const confirmed = await userApi.confirmAvatarUpload(presign.objectKey);
        setUser({ ...user, avatarUrl: confirmed.avatarUrl });
        setAvatarPreviewUrl(confirmed.avatarUrl);
        refreshUserData().catch(() => undefined);
        show('头像已更新', 'success');
      } catch (error) {
        show(getErrorMessage(error), 'error');
      } finally {
        setUploading(false);
        setProgress(0);
      }
    },
    [refreshUserData, setAvatarPreviewUrl, setUser, show, user],
  );

  const pickFromLibrary = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchImageLibrary({
      mediaType: 'photo',
      selectionLimit: 1,
      quality: 0.9,
      assetRepresentationMode: 'compatible',
    });
    if (response.errorMessage) return show(response.errorMessage, 'error');
    await upload(response.assets?.[0]);
  }, [show, upload]);

  const takePhoto = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchCamera({
      mediaType: 'photo',
      quality: 0.9,
      saveToPhotos: false,
      assetRepresentationMode: 'compatible',
    });
    if (response.errorMessage) return show(response.errorMessage, 'error');
    await upload(response.assets?.[0]);
  }, [show, upload]);

  if (!user) return null;
  return (
    <>
      <View style={styles.avatarEditor}>
        <Avatar
          avatarUrl={avatarPreviewUrl}
          name={user.displayName || user.username}
          onImageError={() => setAvatarPreviewUrl(null)}
          onPress={() => {
            if (!uploading) {
              setTabHidden(true);
              setSheetMounted(true);
            }
          }}
          showEditBadge
          size={size}
        />
        {uploading ? (
          <Text style={styles.uploadProgressText}>上传中 {progress}%</Text>
        ) : null}
      </View>
      {sheetMounted ? <BottomSheetModal
        ref={sheetRef}
        backdropComponent={renderBackdrop}
        enableDynamicSizing
        enablePanDownToClose
        onChange={index => setTabHidden(index >= 0)}
        onDismiss={() => {
          setTabHidden(false);
          setSheetMounted(false);
        }}
        backgroundStyle={styles.sheetBackground}
        handleIndicatorStyle={styles.sheetHandle}
      >
        <BottomSheetView style={styles.sheetContent}>
          <Text style={styles.sheetTitle}>更新头像</Text>
          <Text style={styles.sheetCaption}>
            支持 JPG、PNG、WebP，图片不超过 5 MB
          </Text>
          <View style={styles.sheetActions}>
            {Platform.OS !== 'web' ? (
              <AppButton
                label="拍照"
                onPress={takePhoto}
                variant="secondary"
                style={styles.sheetButton}
              />
            ) : null}
            <AppButton
              label="从相册选择"
              onPress={pickFromLibrary}
              style={styles.sheetButton}
            />
          </View>
        </BottomSheetView>
      </BottomSheetModal> : null}
    </>
  );
});

export function ProfileScreen({ navigation }: ProfileProps) {
  const { show } = useToast();
  const user = useSessionStore(state => state.user);
  const profile = useSessionStore(state => state.profile);
  const refreshUserData = useSessionStore(state => state.refreshUserData);
  const signOut = useSessionStore(state => state.signOut);
  const [latestMeasurement, setLatestMeasurement] =
    useState<BodyMeasurement | null>(null);
  const [resourceCounts, setResourceCounts] = useState({
    goals: 0,
    allergies: 0,
    conditions: 0,
    restrictions: 0,
  });
  const [refreshing, setRefreshing] = useState(false);
  // 数据到达后的渲染标记为低优先级（transition）：手动刷新时用户可能正在交互，
  // 数据渲染让位于点击/滚动，降低整页重渲染抢帧的感知。
  const [, startTransition] = useTransition();

  const loadHealthSummary = useCallback(async (force = false) => {
    const { measurements, goals, allergies, conditions, restrictions } =
      await getHealthRecords(force);
    startTransition(() => {
      setLatestMeasurement(
        [...measurements].sort((a, b) =>
          b.measuredAt.localeCompare(a.measuredAt),
        )[0] || null,
      );
      setResourceCounts({
        goals: goals.length,
        allergies: allergies.length,
        conditions: conditions.length,
        restrictions: restrictions.length,
      });
    });
  }, [startTransition]);

  useFocusEffect(useCallback(() => {
    const cancel = scheduleIdleTask(() => {
      loadHealthSummary().catch(() => undefined);
    });
    return cancel;
  }, [loadHealthSummary]));

  const refresh = async () => {
    setRefreshing(true);
    try {
      await Promise.all([refreshUserData(), loadHealthSummary(true)]);
      show('资料已刷新', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setRefreshing(false);
    }
  };

  if (!user) {
    return (
      <AppScreen>
        <EmptyState
          title="暂时无法读取账户"
          description="请刷新页面，或退出后重新登录。"
          action={<AppButton label="重新加载" onPress={refresh} />}
        />
      </AppScreen>
    );
  }

  return (
    <AppScreen
      header={
        <ScreenHeader
          title="我的"
          subtitle="你的健康档案"
          action={
            <Pressable
              accessibilityLabel="刷新资料"
              onPress={refresh}
              style={styles.refreshButton}
            >
              <RefreshCw color={colors.blue} size={16} />
            </Pressable>
          }
        />
      }
    >

      {/*邮箱验证*/}
      <GlassCard variant="soft" style={styles.identityCard}>
        <AvatarEditor size={56} />
        <View style={styles.identityCopy}>
          <Text style={styles.identityName}>
            {user.displayName || user.username}
          </Text>
          <Text style={styles.identityMeta}>
            ID · {user.userId.slice(0, 8)} ·{' '}
            {profile?.gender ? genderLabels[profile.gender] : '未设置'}
          </Text>
          <Text numberOfLines={1} style={styles.identityEmail}>
            {user.email || '未绑定邮箱'}
          </Text>
        </View>
        <Tag
          label={user.emailVerified ? '邮箱已验证' : '待验证'}
          tone={user.emailVerified ? 'green' : 'amber'}
        />
      </GlassCard>

      <View style={styles.actionGrid}>
        <ProfileAction
          icon={<Pencil color={colors.blue} size={18} />}
          label="编辑基础档案"
          onPress={() => navigation.navigate('EditProfile')}
        />
        <ProfileAction
          icon={<FileText color={colors.blue} size={18} />}
          label="我的报告"
          onPress={() =>
            navigation.getParent()?.navigate('ReportsTab' as never)
          }
        />
      </View>

      {!profile?.profileCompletedAt ? (
        <Pressable accessibilityRole="button" onPress={() => navigation.navigate('EditProfile')} style={styles.completeProfilePrompt}>
          <View><Text style={styles.completeProfileTitle}>继续完善基础档案</Text><Text style={styles.completeProfileText}>补充出生日期、性别、身高与活动水平，获得更贴合的健康参考。</Text></View><ChevronRight color={colors.blue} size={19} />
        </Pressable>
      ) : null}

      <SectionTitle
        title="基础档案"
        action={
          <Pressable onPress={() => navigation.navigate('EditProfile')}>
            <Text style={styles.editText}>编辑</Text>
          </Pressable>
        }
      />
      <GlassCard elevated={false} variant="soft" style={styles.infoCard}>
        <InfoRow
          icon={ICON_GENDER}
          label="性别"
          value={profile?.gender ? genderLabels[profile.gender] : '待完善'}
        />
        <InfoRow
          icon={ICON_BIRTHDATE}
          label="出生日期"
          value={displayValue(profile?.birthDate)}
        />
        <InfoRow
          icon={ICON_HEIGHT}
          label="身高"
          value={displayValue(profile?.heightCm, ' cm')}
        />
        <InfoRow
          icon={ICON_ACTIVITY}
          label="活动水平"
          value={
            profile?.activityLevel
              ? activityLabels[profile.activityLevel]
              : '待完善'
          }
        />
        <InfoRow
          icon={ICON_WATER}
          label="每日饮水目标"
          value={displayValue(profile?.dailyWaterTargetMl, ' ml')}
          showDivider={false}
        />
      </GlassCard>

      <SectionTitle
        title="健康记录"
        detail="可随时补充与更新健康信息"
        action={<Pressable onPress={() => navigation.navigate('HealthRecords')}><Text style={styles.editText}>管理</Text></Pressable>}
      />
      <GlassCard elevated={false} variant="soft" style={styles.infoCard}>
        <InfoRow
          icon={ICON_WEIGHT}
          label="最近体重"
          value={displayValue(latestMeasurement?.weightKg, ' kg')}
        />
        <InfoRow
          icon={ICON_HEART_RATE}
          label="最近心率"
          value={displayValue(latestMeasurement?.restingHeartRate, ' bpm')}
        />
        <InfoRow
          icon={ICON_ALLERGY}
          label="过敏记录"
          value={`${resourceCounts.allergies} 条`}
          accent={resourceCounts.allergies ? 'amber' : undefined}
        />
        <InfoRow
          icon={ICON_CONDITION}
          label="疾病记录"
          value={`${resourceCounts.conditions} 条`}
          accent={resourceCounts.conditions ? 'red' : undefined}
        />
        <InfoRow
          icon={ICON_RESTRICTION}
          label="饮食限制"
          value={`${resourceCounts.restrictions} 条`}
        />
        <InfoRow
          icon={ICON_HEART_RATE}
          label="健康目标"
          value={`${resourceCounts.goals} 条`}
          showDivider={false}
        />
      </GlassCard>

      <AppButton
        label={refreshing ? '正在刷新…' : '刷新健康数据'}
        loading={refreshing}
        onPress={refresh}
        variant="secondary"
      />
      <AppButton
        label="退出登录"
        onPress={signOut}
        variant="danger"
        style={styles.logoutButton}
      />
    </AppScreen>
  );
}

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
      render={({
        field: { onBlur, onChange, value },
        fieldState: { error },
      }) => date ? (
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
      )}
    />
  );
}

function ProfileNumericWheel({ control, name, label, minimum, maximum, step, unit }: {
  control: Control<EditForm>;
  name: 'heightCm' | 'dailyWaterTargetMl';
  label: string;
  minimum: number;
  maximum: number;
  step: number;
  unit: string;
}) {
  return <Controller control={control} name={name} render={({ field: { onBlur, onChange, value } }) => (
    <NumericWheelField label={label} maximum={maximum} minimum={minimum} onChange={nextValue => { onChange(nextValue); onBlur(); }} step={step} unit={unit} value={value} />
  )} />;
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
  options: Array<{ value: T; label: string; description?: string }>;
}) {
  return <HealthSelectField label={label} onChange={next => onChange(next as T)} options={options as HealthPickerOption[]} value={value} />;
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
  const gender = useWatch({ control, name: 'gender' });
  const activityLevel = useWatch({ control, name: 'activityLevel' });
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
        navigation.reset({ index: 0, routes: [{ name: 'ProfileMain' }] });
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
      <AppScreen
        header={
          <ScreenHeader title="编辑档案" onBack={() => navigation.goBack()} />
        }
      >
        <EmptyState
          title="没有可编辑的档案"
          description="请先返回上一页刷新。"
        />
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
              { value: 'male', label: '男', description: '用于基础健康参考' },
              { value: 'female', label: '女', description: '用于基础健康参考' },
              { value: 'other', label: '其他', description: '使用中性健康建议' },
              { value: 'unknown', label: '暂不说明', description: '之后可随时补充' },
            ]}
          />
          <ProfileNumericWheel control={control} label="身高" maximum={300} minimum={50} name="heightCm" step={0.1} unit="cm" />
          <ChoiceGroup
            label="活动水平"
            value={activityLevel}
            onChange={value => setValue('activityLevel', value)}
            options={Object.entries(activityLabels).map(([value, label]) => ({
              value: value as ActivityLevel,
              label,
              description: value === 'sedentary' ? '日常久坐，运动较少' : value === 'light' ? '偶尔步行或轻运动' : value === 'moderate' ? '规律中等强度活动' : value === 'active' ? '每周高频运动' : '高强度或体力活动较多',
            }))}
          />
          <ProfileNumericWheel control={control} label="每日饮水目标" maximum={10000} minimum={0} name="dailyWaterTargetMl" step={100} unit="ml" />
        </View>
      </GlassCard>
      {saveError ? <Text style={styles.saveError}>{saveError}</Text> : null}
      <AppButton label="保存基础档案" loading={saving} onPress={save} />
    </AppScreen>
  );
}

const styles = StyleSheet.create({
  refreshButton: {
    width: 30,
    height: 30,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 15,
    backgroundColor: 'rgba(255,255,255,0.62)',
  },
  identityCard: {
    flexDirection: 'row',
    gap: spacing.md,
    alignItems: 'center',
    padding: spacing.lg,
  },
  completeProfilePrompt: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderRadius: radii.md, borderWidth: 1, borderColor: '#B9DBFA', backgroundColor: colors.blueSoft, padding: spacing.md },
  completeProfileTitle: { color: colors.blue, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' },
  completeProfileText: { flex: 1, color: colors.muted, fontFamily: fonts.body, fontSize: 11, lineHeight: 16, marginTop: 3 },
  identityCopy: { flex: 1, gap: 3 },
  identityName: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 20,
    fontWeight: '800',
  },
  identityMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 },
  identityEmail: { color: colors.placeholder, fontFamily: fonts.body, fontSize: 10 },
  actionGrid: { flexDirection: 'row', gap: spacing.md },
  profileAction: {
    flex: 1,
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 8,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.surface,
  },
  profileActionIcon: {
    width: 32,
    height: 32,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
  },
  profileActionLabel: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    flex: 1,
  },
  editText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
  infoCard: { paddingVertical: 4 },
  infoRow: {
    minHeight: 47,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.md,
    paddingVertical: 5,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(230,237,245,0.72)',
  },
  infoRowLast: { borderBottomWidth: 0 },
  infoLead: { flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 },
  infoIcon: { width: 20, alignItems: 'center' },
  infoLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 13 },
  infoValueSlot: { width: 108, alignItems: 'flex-end' },
  infoValueTag: { alignSelf: 'flex-end' },
  infoValue: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    width: '100%',
    textAlign: 'right',
  },
  logoutButton: { marginTop: spacing.sm },
  avatarEditor: { alignItems: 'center' },
  uploadProgressText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 10,
    fontWeight: '800',
    marginTop: 6,
  },
  sheetBackground: {
    backgroundColor: '#FFFFFF',
    borderColor: '#D4E2EF',
    borderRadius: radii.lg,
    borderWidth: 1,
  },
  sheetHandle: { backgroundColor: '#CBD5E1', width: 38 },
  sheetContent: { paddingHorizontal: spacing.xl, paddingBottom: spacing.xl },
  sheetTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
    textAlign: 'center',
  },
  sheetCaption: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    textAlign: 'center',
    marginTop: 6,
  },
  sheetActions: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.lg,
  },
  sheetButton: { flex: 1 },
  formSpace: { marginTop: spacing.lg, gap: spacing.md },
  formField: { marginBottom: spacing.md },
  formLabel: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 7,
  },
  formInputError: { borderColor: colors.red },
  formError: {
    color: '#C93025',
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 5,
  },
  choiceGroup: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 },
  choice: {
    borderRadius: radii.pill,
    backgroundColor: '#F1F5F9',
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  choiceActive: {
    backgroundColor: colors.blueSoft,
    borderWidth: 1,
    borderColor: '#B9DBFA',
  },
  choiceText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '700',
  },
  choiceTextActive: { color: colors.blue },
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
