import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Controller, useForm, type Control, type RegisterOptions } from 'react-hook-form';
import { Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BottomSheetModal, BottomSheetView } from '@gorhom/bottom-sheet';
import { launchCamera, launchImageLibrary, type Asset } from 'react-native-image-picker';
import { Activity, Ban, Cake, ChevronRight, Droplets, FileText, HeartPulse, KeyRound, Pencil, RefreshCw, Ruler, Scale, ShieldAlert, Stethoscope, Target, UserRound, Utensils } from 'lucide-react-native';

import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { AppButton, AppScreen, Avatar, EmptyState, GlassCard, MetricProgress, ScreenHeader, SectionTitle, Tag, inputStyle } from '../../../shared/components/ui';
import { useToast } from '../../../shared/components/Toast';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { ActivityLevel, Gender, HealthGoal, ProfileUpdatePayload } from '../../../shared/types/api';
import { userApi } from '../api/userApi';
import { useSessionStore } from '../../auth/store/sessionStore';
import { prepareAvatarFile, uploadAvatarBinary } from '../services/avatarUpload';

type ProfileProps = NativeStackScreenProps<ProfileStackParamList, 'ProfileMain'>;
type EditProps = NativeStackScreenProps<ProfileStackParamList, 'EditProfile'>;
type PasswordProps = NativeStackScreenProps<ProfileStackParamList, 'ChangePassword'>;

const genderLabels: Record<Gender, string> = { male: '男', female: '女', other: '其他' };
const activityLabels: Record<ActivityLevel, string> = { sedentary: '久坐', light: '轻度活动', moderate: '中度活动', active: '活跃', very_active: '高强度活动' };
const goalLabels: Record<HealthGoal, string> = { weight_loss: '减重', muscle_gain: '增肌', maintain: '维持体重', health_improve: '改善健康' };

function displayValue(value: string | number | null | undefined, suffix = ''): string {
  return value === null || value === undefined || value === '' ? '待完善' : `${value}${suffix}`;
}

function tagsToText(tags: string[]): string {
  return tags.length ? tags.join('、') : '未设置';
}

function InfoRow({ icon, label, value, accent }: { icon: React.ReactNode; label: string; value: string; accent?: 'green' | 'amber' | 'red' }) {
  return (
    <View style={styles.infoRow}>
      <View style={styles.infoLead}><View style={styles.infoIcon}>{icon}</View><Text style={styles.infoLabel}>{label}</Text></View>
      {accent ? <Tag label={value} tone={accent} /> : <Text numberOfLines={2} style={styles.infoValue}>{value}</Text>}
    </View>
  );
}

function ProfileAction({ icon, label, onPress }: { icon: React.ReactNode; label: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.profileAction, pressed && styles.pressed]}>
      <View style={styles.profileActionIcon}>{icon}</View>
      <Text style={styles.profileActionLabel}>{label}</Text>
      <ChevronRight color={colors.muted} size={18} />
    </Pressable>
  );
}

/**
 * 选择、上传与确认被封装在同一处：页面只负责决定入口，避免遗漏确认接口而产生孤儿文件。
 * 底部表单使用系统手势动画；上传时只更新进度文字，不触发整页重渲染。
 */
function AvatarEditor({ size = 60 }: { size?: number }) {
  const sheetRef = useRef<BottomSheetModal>(null);
  const snapPoints = useMemo(() => [224], []);
  const user = useSessionStore(state => state.user);
  const avatarPreviewUrl = useSessionStore(state => state.avatarPreviewUrl);
  const setUser = useSessionStore(state => state.setUser);
  const setAvatarPreviewUrl = useSessionStore(state => state.setAvatarPreviewUrl);
  const { show } = useToast();
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);

  const upload = useCallback(async (asset?: Asset) => {
    if (!asset || !user) {
      return;
    }

    setUploading(true);
    setProgress(0);
    try {
      const file = await prepareAvatarFile(asset);
      const presign = await userApi.createAvatarUpload({ fileName: file.fileName, contentType: file.contentType });
      await uploadAvatarBinary(file, presign.uploadUrl, setProgress);
      const confirmed = await userApi.confirmAvatarUpload(presign.objectKey);
      // 先保存对象键以保持与服务端模型一致，再存可直接显示的临时 URL。
      setUser({ ...user, avatarUrl: presign.objectKey });
      setAvatarPreviewUrl(confirmed.avatarUrl);
      show('头像已更新', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setUploading(false);
      setProgress(0);
    }
  }, [setAvatarPreviewUrl, setUser, show, user]);

  const pickFromLibrary = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchImageLibrary({ mediaType: 'photo', selectionLimit: 1, quality: 0.9, assetRepresentationMode: 'compatible' });
    if (response.errorMessage) {
      show(response.errorMessage, 'error');
      return;
    }
    await upload(response.assets?.[0]);
  }, [show, upload]);

  const takePhoto = useCallback(async () => {
    sheetRef.current?.dismiss();
    const response = await launchCamera({ mediaType: 'photo', quality: 0.9, saveToPhotos: false, assetRepresentationMode: 'compatible' });
    if (response.errorMessage) {
      show(response.errorMessage, 'error');
      return;
    }
    await upload(response.assets?.[0]);
  }, [show, upload]);

  if (!user) {
    return null;
  }

  return (
    <>
      <View style={styles.avatarEditor}>
        <Avatar
          avatarUrl={avatarPreviewUrl}
          name={user.nickname || user.username}
          onImageError={() => setAvatarPreviewUrl(null)}
          onPress={() => !uploading && sheetRef.current?.present()}
          showEditBadge
          size={size}
        />
        {uploading ? <View style={styles.uploadProgress}><Text style={styles.uploadProgressText}>上传中 {progress}%</Text></View> : null}
      </View>
      <BottomSheetModal ref={sheetRef} enableDynamicSizing={false} snapPoints={snapPoints} backgroundStyle={styles.sheetBackground} handleIndicatorStyle={styles.sheetHandle}>
        <BottomSheetView style={styles.sheetContent}>
          <Text style={styles.sheetTitle}>更新头像</Text>
          <Text style={styles.sheetCaption}>支持 JPG、PNG、WebP，图片不超过 5 MB</Text>
          <View style={styles.sheetActions}>
            {Platform.OS !== 'web' ? <AppButton label="拍照" onPress={takePhoto} variant="secondary" style={styles.sheetButton} /> : null}
            <AppButton label="从相册选择" onPress={pickFromLibrary} style={styles.sheetButton} />
          </View>
        </BottomSheetView>
      </BottomSheetModal>
    </>
  );
}

export function ProfileScreen({ navigation }: ProfileProps) {
  const { show } = useToast();
  const user = useSessionStore(state => state.user);
  const profile = useSessionStore(state => state.profile);
  const profileMissing = useSessionStore(state => state.profileMissing);
  const refreshUserData = useSessionStore(state => state.refreshUserData);
  const signOut = useSessionStore(state => state.signOut);
  const [refreshing, setRefreshing] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);

  const refresh = async () => {
    setRefreshing(true);
    try {
      await refreshUserData();
      show('资料已刷新', 'success');
    } catch (error) {
      show(getErrorMessage(error), 'error');
    } finally {
      setRefreshing(false);
    }
  };

  const logout = async () => {
    setLoggingOut(true);
    await signOut();
  };

  if (!user) {
    return (
      <AppScreen>
        <EmptyState title="暂时无法读取账户" description="请刷新页面，或退出后重新登录。" action={<AppButton label="重新加载" onPress={refresh} />} />
      </AppScreen>
    );
  }

  return (
    <AppScreen>
      <ScreenHeader
        title="我的"
        subtitle="你的健康档案"
        onBack={() => navigation.getParent()?.navigate('HomeTab' as never)}
        action={<Pressable accessibilityLabel="刷新资料" onPress={refresh} style={styles.refreshButton}><RefreshCw color={colors.blue} size={18} /></Pressable>}
      />
      <GlassCard style={styles.identityCard}>
        <AvatarEditor size={66} />
        <View style={styles.identityCopy}>
          <Text style={styles.identityName}>{user.nickname || user.username}</Text>
          <Text style={styles.identityMeta}>ID · {user.userId.slice(0, 8)} · {profile?.gender ? genderLabels[profile.gender] : '未设置'} {profile?.age ? `${profile.age}岁` : ''}</Text>
          <Text numberOfLines={1} style={styles.identityEmail}>{user.email}</Text>
        </View>
        <View style={styles.identityTags}>
          <Tag label={profile?.bmi && profile.bmi >= 24 ? '风险：中' : '风险：低'} tone={profile?.bmi && profile.bmi >= 24 ? 'amber' : 'green'} />
          {profile?.healthGoal ? <Tag label={`◎ ${goalLabels[profile.healthGoal]}`} tone="green" /> : null}
        </View>
      </GlassCard>

      <View style={styles.actionGrid}>
        <ProfileAction icon={<Pencil color={colors.blue} size={18} />} label="编辑个人资料" onPress={() => profile ? navigation.navigate('EditProfile') : show('当前账户没有可编辑的健康画像。', 'error')} />
        <ProfileAction icon={<FileText color={colors.blue} size={18} />} label="我的报告" onPress={() => navigation.getParent()?.navigate('ReportsTab' as never)} />
      </View>

      {profileMissing ? (
        <EmptyState title="健康画像尚未建立" description="当前 Orion 服务没有提供客户端创建画像接口，请联系管理员初始化画像后再编辑。" action={<AppButton label={refreshing ? '正在刷新…' : '重新读取'} disabled={refreshing} onPress={refresh} variant="secondary" />} />
      ) : profile ? (
        <>
          <SectionTitle title="基础健康信息" action={<Pressable onPress={() => navigation.navigate('EditProfile')}><Text style={styles.editText}>编辑</Text></Pressable>} />
          <GlassCard style={styles.infoCard}>
            <InfoRow icon={<UserRound color={colors.muted} size={17} />} label="性别" value={profile.gender ? genderLabels[profile.gender] : '待完善'} />
            <InfoRow icon={<Cake color={colors.muted} size={17} />} label="年龄" value={displayValue(profile.age, ' 岁')} />
            <InfoRow icon={<Ruler color={colors.muted} size={17} />} label="身高" value={displayValue(profile.heightCm, ' cm')} />
            <InfoRow icon={<Scale color={colors.muted} size={17} />} label="体重" value={displayValue(profile.weightKg, ' kg')} />
            <InfoRow icon={<HeartPulse color={colors.muted} size={17} />} label="BMI" value={displayValue(profile.bmi)} accent={profile.bmi && profile.bmi >= 24 ? 'amber' : undefined} />
          </GlassCard>

          <SectionTitle title="健康目标与习惯" />
          <GlassCard style={styles.infoCard}>
            <InfoRow icon={<Target color={colors.muted} size={17} />} label="健康目标" value={profile.healthGoal ? goalLabels[profile.healthGoal] : '待完善'} />
            <InfoRow icon={<Activity color={colors.muted} size={17} />} label="活动水平" value={profile.activityLevel ? activityLabels[profile.activityLevel] : '待完善'} />
            <InfoRow icon={<Droplets color={colors.muted} size={17} />} label="每日饮水" value={displayValue(profile.dailyWaterMl, ' ml')} />
            <InfoRow icon={<Utensils color={colors.muted} size={17} />} label="偏好菜系" value={tagsToText(profile.preferredCuisine)} />
          </GlassCard>

          <SectionTitle title="过敏与饮食限制" />
          <GlassCard style={styles.infoCard}>
            <InfoRow icon={<ShieldAlert color={colors.muted} size={17} />} label="过敏原" value={tagsToText(profile.allergies)} accent={profile.allergies.length ? 'amber' : undefined} />
            <InfoRow icon={<Ban color={colors.muted} size={17} />} label="饮食禁忌" value={tagsToText(profile.dietaryRestrictions)} />
            <InfoRow icon={<Stethoscope color={colors.muted} size={17} />} label="疾病情况" value={tagsToText(profile.medicalConditions)} accent={profile.medicalConditions.length ? 'red' : undefined} />
          </GlassCard>

          <GlassCard style={styles.goalCard}>
            <View style={styles.goalHeading}><Target color={colors.green} size={20} /><Text style={styles.goalTitle}>今日目标进度</Text><Text style={styles.goalNote}>演示数据</Text></View>
            <View style={styles.goalMetrics}><MetricProgress label="热量" value={80} color={colors.blue} rightLabel="1,280 / 1,600 kcal" /><MetricProgress label="蛋白质" value={40} color={colors.green} rightLabel="38 / 95 g" /><MetricProgress label="钠摄入" value={82} color={colors.amber} rightLabel="1,640 / 2,000 mg" /></View>
          </GlassCard>

          <Pressable onPress={() => navigation.navigate('ChangePassword')} style={({ pressed }) => [styles.securityLink, pressed && styles.pressed]}>
            <KeyRound color={colors.violet} size={17} />
            <Text style={styles.securityText}>账户安全与修改密码</Text>
            <ChevronRight color={colors.muted} size={18} />
          </Pressable>
        </>
      ) : null}

      <AppButton label="退出登录" loading={loggingOut} onPress={logout} variant="danger" style={styles.logoutButton} />
    </AppScreen>
  );
}

type EditForm = {
  nickname: string;
  age: string;
  gender: Gender | '';
  heightCm: string;
  weightKg: string;
  activityLevel: ActivityLevel | '';
  healthGoal: HealthGoal | '';
  allergies: string;
  dietaryRestrictions: string;
  medicalConditions: string;
  dailyWaterMl: string;
  preferredCuisine: string;
};

function ProfileField({ control, name, label, placeholder, keyboardType = 'default', rules }: {
  control: Control<EditForm>;
  name: keyof EditForm;
  label: string;
  placeholder: string;
  keyboardType?: 'default' | 'numeric';
  rules?: RegisterOptions<EditForm, keyof EditForm>;
}) {
  return (
    <Controller
      control={control}
      name={name}
      rules={rules}
      render={({ field: { onBlur, onChange, value }, fieldState: { error } }) => (
        <View style={styles.formField}>
          <Text style={styles.formLabel}>{label}</Text>
          <TextInput onBlur={onBlur} onChangeText={onChange} placeholder={placeholder} placeholderTextColor="#94A3B8" keyboardType={keyboardType} style={[inputStyle, error && styles.formInputError]} value={value} />
          {error ? <Text style={styles.formError}>{error.message}</Text> : null}
        </View>
      )}
    />
  );
}

function ChoiceGroup<T extends string>({ label, value, onChange, options }: { label: string; value: T | ''; onChange: (value: T) => void; options: Array<{ value: T; label: string }> }) {
  return (
    <View style={styles.formField}>
      <Text style={styles.formLabel}>{label}</Text>
      <View style={styles.choiceGroup}>{options.map(item => <Pressable key={item.value} onPress={() => onChange(item.value)} style={[styles.choice, value === item.value && styles.choiceActive]}><Text style={[styles.choiceText, value === item.value && styles.choiceTextActive]}>{item.label}</Text></Pressable>)}</View>
    </View>
  );
}

function splitTags(value: string): string[] {
  return value.split(/[，,]/).map(item => item.trim()).filter(Boolean);
}

function optionalNumber(value: string): number | undefined {
  if (!value.trim()) {
    return undefined;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function EditProfileScreen({ navigation }: EditProps) {
  const profile = useSessionStore(state => state.profile);
  const user = useSessionStore(state => state.user);
  const avatarPreviewUrl = useSessionStore(state => state.avatarPreviewUrl);
  const setUser = useSessionStore(state => state.setUser);
  const setProfile = useSessionStore(state => state.setProfile);
  const { show } = useToast();
  const { control, handleSubmit, reset, watch, setValue } = useForm<EditForm>({ defaultValues: emptyForm });
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    if (profile && user) {
      reset({
        nickname: user.nickname,
        age: profile.age?.toString() || '',
        gender: profile.gender || '',
        heightCm: profile.heightCm?.toString() || '',
        weightKg: profile.weightKg?.toString() || '',
        activityLevel: profile.activityLevel || '',
        healthGoal: profile.healthGoal || '',
        allergies: profile.allergies.join(', '),
        dietaryRestrictions: profile.dietaryRestrictions.join(', '),
        medicalConditions: profile.medicalConditions.join(', '),
        dailyWaterMl: profile.dailyWaterMl?.toString() || '',
        preferredCuisine: profile.preferredCuisine.join(', '),
      });
    }
  }, [profile, reset, user]);

  if (!profile || !user) {
    return <AppScreen><ScreenHeader title="编辑资料" onBack={navigation.goBack} /><EmptyState title="没有可编辑的画像" description="请先返回“我的”刷新账户资料。" /></AppScreen>;
  }

  const save = handleSubmit(async values => {
    setSaving(true);
    setSaveError(null);
    const payload: ProfileUpdatePayload = {
      age: optionalNumber(values.age),
      gender: values.gender || undefined,
      heightCm: optionalNumber(values.heightCm),
      weightKg: optionalNumber(values.weightKg),
      activityLevel: values.activityLevel || undefined,
      healthGoal: values.healthGoal || undefined,
      allergies: splitTags(values.allergies),
      dietaryRestrictions: splitTags(values.dietaryRestrictions),
      medicalConditions: splitTags(values.medicalConditions),
      dailyWaterMl: optionalNumber(values.dailyWaterMl),
      preferredCuisine: splitTags(values.preferredCuisine),
    };

    try {
      const [nextUser, nextProfile] = await Promise.all([
        values.nickname.trim() !== user.nickname ? userApi.updateSelf(values.nickname.trim()) : Promise.resolve(user),
        userApi.updateProfile(payload),
      ]);
      setUser(nextUser);
      setProfile(nextProfile);
      show('个人资料已保存', 'success');
      navigation.goBack();
    } catch (error) {
      setSaveError(getErrorMessage(error));
    } finally {
      setSaving(false);
    }
  });

  return (
    <AppScreen>
      <ScreenHeader title="编辑资料" subtitle="保存后会同步到 Orion 用户服务" onBack={() => navigation.goBack()} />
      <GlassCard>
        <SectionTitle title="账户信息" detail="点击头像可更换图片" />
        <View style={styles.accountEditor}><AvatarEditor size={76} /><View style={styles.accountEditorCopy}><Text style={styles.accountEditorName}>{user.nickname || user.username}</Text><Text style={styles.accountEditorHint}>{avatarPreviewUrl ? '点击头像即可重新上传' : '当前使用昵称渐变头像'}</Text></View></View>
        <View style={styles.formSpace}><ProfileField control={control} name="nickname" label="昵称" placeholder="输入显示名称" rules={{ required: '昵称不能为空' }} /></View>
      </GlassCard>
      <GlassCard>
        <SectionTitle title="基础健康信息" />
        <View style={styles.formSpace}>
          <ProfileField control={control} name="age" label="年龄" placeholder="例如 28" keyboardType="numeric" rules={{ validate: value => !value || (Number(value) > 0 && Number(value) < 150) || '请输入有效年龄' }} />
          <ChoiceGroup label="性别" value={watch('gender')} onChange={value => setValue('gender', value)} options={[{ value: 'male', label: '男' }, { value: 'female', label: '女' }, { value: 'other', label: '其他' }]} />
          <ProfileField control={control} name="heightCm" label="身高（cm）" placeholder="例如 175" keyboardType="numeric" rules={{ validate: value => !value || (Number(value) > 50 && Number(value) < 260) || '请输入有效身高' }} />
          <ProfileField control={control} name="weightKg" label="体重（kg）" placeholder="例如 65.5" keyboardType="numeric" rules={{ validate: value => !value || (Number(value) > 10 && Number(value) < 500) || '请输入有效体重' }} />
        </View>
      </GlassCard>
      <GlassCard>
        <SectionTitle title="目标与饮食习惯" />
        <View style={styles.formSpace}>
          <ChoiceGroup label="活动水平" value={watch('activityLevel')} onChange={value => setValue('activityLevel', value)} options={[{ value: 'sedentary', label: '久坐' }, { value: 'light', label: '轻度' }, { value: 'moderate', label: '中度' }, { value: 'active', label: '活跃' }, { value: 'very_active', label: '高强度' }]} />
          <ChoiceGroup label="健康目标" value={watch('healthGoal')} onChange={value => setValue('healthGoal', value)} options={[{ value: 'weight_loss', label: '减重' }, { value: 'muscle_gain', label: '增肌' }, { value: 'maintain', label: '维持' }, { value: 'health_improve', label: '改善健康' }]} />
          <ProfileField control={control} name="dailyWaterMl" label="每日饮水目标（ml）" placeholder="例如 2000" keyboardType="numeric" rules={{ validate: value => !value || (Number(value) > 0 && Number(value) < 10000) || '请输入有效饮水量' }} />
          <ProfileField control={control} name="preferredCuisine" label="偏好菜系" placeholder="用中文逗号或英文逗号分隔" />
        </View>
      </GlassCard>
      <GlassCard>
        <SectionTitle title="过敏与限制" detail="多个项目请用逗号分隔" />
        <View style={styles.formSpace}>
          <ProfileField control={control} name="allergies" label="过敏原" placeholder="例如 花生, 海鲜" />
          <ProfileField control={control} name="dietaryRestrictions" label="饮食禁忌" placeholder="例如 高钠食物" />
          <ProfileField control={control} name="medicalConditions" label="疾病情况" placeholder="例如 高血压" />
        </View>
      </GlassCard>
      {saveError ? <Text style={styles.saveError}>{saveError}</Text> : null}
      <AppButton label="保存全部资料" loading={saving} onPress={save} />
    </AppScreen>
  );
}

const emptyForm: EditForm = { nickname: '', age: '', gender: '', heightCm: '', weightKg: '', activityLevel: '', healthGoal: '', allergies: '', dietaryRestrictions: '', medicalConditions: '', dailyWaterMl: '', preferredCuisine: '' };

type PasswordForm = { oldPassword: string; newPassword: string; confirmPassword: string };

export function ChangePasswordScreen({ navigation }: PasswordProps) {
  const { control, handleSubmit, watch } = useForm<PasswordForm>({ defaultValues: { oldPassword: '', newPassword: '', confirmPassword: '' } });
  const { show } = useToast();
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const submit = handleSubmit(async values => {
    setSaving(true);
    setSaveError(null);
    try {
      await userApi.changePassword(values.oldPassword, values.newPassword);
      show('密码已修改', 'success');
      navigation.goBack();
    } catch (error) {
      setSaveError(getErrorMessage(error));
    } finally {
      setSaving(false);
    }
  });

  return (
    <AppScreen>
      <ScreenHeader title="修改密码" subtitle="保存后请使用新密码登录" onBack={() => navigation.goBack()} />
      <GlassCard>
        <Text style={styles.passwordHint}>为保护账户安全，请先验证当前密码。新密码长度需为 6–100 个字符。</Text>
        <PasswordField control={control} name="oldPassword" label="当前密码" rules={{ required: '请输入当前密码' }} />
        <PasswordField control={control} name="newPassword" label="新密码" rules={{ required: '请输入新密码', minLength: { value: 6, message: '新密码至少 6 个字符' }, maxLength: { value: 100, message: '新密码最多 100 个字符' } }} />
        <PasswordField control={control} name="confirmPassword" label="确认新密码" rules={{ required: '请再次输入新密码', validate: value => value === watch('newPassword') || '两次输入的密码不一致' }} />
      </GlassCard>
      {saveError ? <Text style={styles.saveError}>{saveError}</Text> : null}
      <AppButton label="确认修改密码" loading={saving} onPress={submit} />
    </AppScreen>
  );
}

function PasswordField({ control, name, label, rules }: { control: Control<PasswordForm>; name: keyof PasswordForm; label: string; rules: RegisterOptions<PasswordForm, keyof PasswordForm> }) {
  return (
    <Controller control={control} name={name} rules={rules} render={({ field: { onBlur, onChange, value }, fieldState: { error } }) => (
      <View style={styles.formField}>
        <Text style={styles.formLabel}>{label}</Text>
        <TextInput accessibilityLabel={label} autoCapitalize="none" autoCorrect={false} onBlur={onBlur} onChangeText={onChange} placeholder="输入密码" placeholderTextColor="#94A3B8" secureTextEntry style={[inputStyle, error && styles.formInputError]} value={value} />
        {error ? <Text style={styles.formError}>{error.message}</Text> : null}
      </View>
    )} />
  );
}

const styles = StyleSheet.create({
  refreshButton: { width: 38, height: 38, alignItems: 'center', justifyContent: 'center', borderRadius: 19, backgroundColor: colors.blueSoft },
  identityCard: { flexDirection: 'row', gap: spacing.md, alignItems: 'center', padding: spacing.lg },
  identityCopy: { flex: 1, gap: 3 },
  identityName: { color: colors.ink, fontFamily: fonts.display, fontSize: 20, fontWeight: '800' },
  identityMeta: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 },
  identityEmail: { color: '#94A3B8', fontFamily: fonts.body, fontSize: 10 },
  identityTags: { alignItems: 'flex-end', gap: 6 },
  actionGrid: { flexDirection: 'row', gap: spacing.md },
  profileAction: { flex: 1, minHeight: 64, flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, borderRadius: radii.md, borderWidth: 1, borderColor: colors.glassBorder, backgroundColor: colors.glassStrong, boxShadow: '0 8px 16px rgba(91,120,149,0.08)' },
  profileActionIcon: { width: 32, height: 32, borderRadius: 11, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft },
  profileActionLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700', flex: 1 },
  pressed: { opacity: 0.72 },
  editText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  infoCard: { paddingVertical: 4 },
  infoRow: { minHeight: 47, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.md, paddingVertical: 5, borderBottomWidth: 1, borderBottomColor: 'rgba(230,237,245,0.72)' },
  infoLead: { flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 },
  infoIcon: { width: 20, alignItems: 'center' },
  infoLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 13 },
  infoValue: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700', maxWidth: '62%', textAlign: 'right' },
  goalCard: { backgroundColor: '#F0FAF4' },
  goalHeading: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  goalTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 16, fontWeight: '800', flex: 1 },
  goalNote: { color: colors.muted, fontFamily: fonts.body, fontSize: 10 },
  goalMetrics: { gap: spacing.md, marginTop: spacing.lg },
  securityLink: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 9, paddingHorizontal: 4 },
  securityText: { flex: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  logoutButton: { marginTop: spacing.sm },
  avatarEditor: { alignItems: 'center' },
  uploadProgress: { alignSelf: 'flex-start', marginTop: 6, marginLeft: 4, backgroundColor: colors.blueSoft, borderRadius: radii.pill, paddingHorizontal: 8, paddingVertical: 4 },
  uploadProgressText: { color: colors.blue, fontFamily: fonts.body, fontSize: 10, fontWeight: '800' },
  sheetBackground: { backgroundColor: '#F8FBFE', borderRadius: radii.lg },
  sheetHandle: { backgroundColor: '#CBD5E1', width: 38 },
  sheetContent: { paddingHorizontal: spacing.xl, paddingBottom: spacing.xl },
  sheetTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800', textAlign: 'center' },
  sheetCaption: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, textAlign: 'center', marginTop: 6 },
  sheetActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.lg },
  sheetButton: { flex: 1 },
  accountEditor: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.lg },
  accountEditorCopy: { flex: 1, gap: 3 },
  accountEditorName: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  accountEditorHint: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  formSpace: { marginTop: spacing.lg, gap: spacing.md },
  formField: { marginBottom: spacing.md },
  formLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700', marginBottom: 7 },
  formInputError: { borderColor: colors.red },
  formError: { color: '#C93025', fontFamily: fonts.body, fontSize: 11, marginTop: 5 },
  choiceGroup: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 },
  choice: { borderRadius: radii.pill, backgroundColor: '#F1F5F9', paddingHorizontal: 12, paddingVertical: 8 },
  choiceActive: { backgroundColor: colors.blueSoft, borderWidth: 1, borderColor: '#B9DBFA' },
  choiceText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' },
  choiceTextActive: { color: colors.blue },
  saveError: { color: '#C93025', backgroundColor: colors.redSoft, borderRadius: radii.sm, fontFamily: fonts.body, fontSize: 12, lineHeight: 18, padding: spacing.sm },
  passwordHint: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 19, marginBottom: spacing.lg },
});
