import React, { memo, useCallback, useState, useTransition } from 'react';
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
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useFocusEffect } from '@react-navigation/native';
import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { PressableScale } from '../../../shared/animation/PressableScale';
import {
  AppButton,
  AppScreen,
  EmptyState,
  GlassCard,
  ScreenHeader,
  SectionTitle,
  Tag,
  useToast,
} from '../../../shared/components';
import { scheduleIdleTask } from '../../../shared/perf/scheduleIdleTask';
import { colors, fonts, radii, spacing } from '../../../shared/theme/tokens';
import type { ActivityLevel, BodyMeasurement, Gender } from '../api/profileTypes';
import { useSessionStore } from '../../../app/session/sessionStore';
import { getHealthRecords } from '../services/healthRecords';
import { AvatarEditor } from '../components/AvatarEditor';
type ProfileProps = NativeStackScreenProps<ProfileStackParamList, 'ProfileMain'>;
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
function displayValue(value: string | number | null | undefined, suffix = ''): string {
  return value === null || value === undefined || value === '' ? '待完善' : `${value}${suffix}`;
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
    <PressableScale accessibilityRole="button" onPress={onPress} style={styles.profileAction}>
      <View style={styles.profileActionIcon}>{icon}</View>
      <Text numberOfLines={1} style={styles.profileActionLabel} adjustsFontSizeToFit={true}>
        {label}
      </Text>
      <ChevronRight color={colors.muted} size={16} />
    </PressableScale>
  );
});
export function ProfileScreen({ navigation }: ProfileProps) {
  const { show } = useToast();
  const user = useSessionStore(state => state.user);
  const profile = useSessionStore(state => state.profile);
  const refreshUserData = useSessionStore(state => state.refreshUserData);
  const signOut = useSessionStore(state => state.signOut);
  const [latestMeasurement, setLatestMeasurement] = useState<BodyMeasurement | null>(null);
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
  const loadHealthSummary = useCallback(
    async (force = false) => {
      const { measurements, goals, allergies, conditions, restrictions } = await getHealthRecords(
        force,
      );
      startTransition(() => {
        setLatestMeasurement(
          [...measurements].sort((a, b) => b.measuredAt.localeCompare(a.measuredAt))[0] || null,
        );
        setResourceCounts({
          goals: goals.length,
          allergies: allergies.length,
          conditions: conditions.length,
          restrictions: restrictions.length,
        });
      });
    },
    [startTransition],
  );
  useFocusEffect(
    useCallback(() => {
      const cancel = scheduleIdleTask(() => {
        loadHealthSummary().catch(() => undefined);
      });
      return cancel;
    }, [loadHealthSummary]),
  );
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
            <Pressable accessibilityLabel="刷新资料" onPress={refresh} style={styles.refreshButton}>
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
          <Text style={styles.identityName}>{user.displayName || user.username}</Text>
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
          onPress={() => navigation.getParent()?.navigate('ReportsTab' as never)}
        />
      </View>

      {!profile?.profileCompletedAt ? (
        <Pressable
          accessibilityRole="button"
          onPress={() => navigation.navigate('EditProfile')}
          style={styles.completeProfilePrompt}
        >
          <View>
            <Text style={styles.completeProfileTitle}>继续完善基础档案</Text>
            <Text style={styles.completeProfileText}>
              补充出生日期、性别、身高与活动水平，获得更贴合的健康参考。
            </Text>
          </View>
          <ChevronRight color={colors.blue} size={19} />
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
        <InfoRow icon={ICON_BIRTHDATE} label="出生日期" value={displayValue(profile?.birthDate)} />
        <InfoRow icon={ICON_HEIGHT} label="身高" value={displayValue(profile?.heightCm, ' cm')} />
        <InfoRow
          icon={ICON_ACTIVITY}
          label="活动水平"
          value={profile?.activityLevel ? activityLabels[profile.activityLevel] : '待完善'}
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
        action={
          <Pressable onPress={() => navigation.navigate('HealthRecords')}>
            <Text style={styles.editText}>管理</Text>
          </Pressable>
        }
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
      <AppButton label="退出登录" onPress={signOut} variant="danger" style={styles.logoutButton} />
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
  completeProfilePrompt: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: '#B9DBFA',
    backgroundColor: colors.blueSoft,
    padding: spacing.md,
  },
  completeProfileTitle: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 14,
    fontWeight: '800',
  },
  completeProfileText: {
    flex: 1,
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    lineHeight: 16,
    marginTop: 3,
  },
  identityCopy: {
    flex: 1,
    gap: 3,
  },
  identityName: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 20,
    fontWeight: '800',
  },
  identityMeta: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
  },
  identityEmail: {
    color: colors.placeholder,
    fontFamily: fonts.body,
    fontSize: 10,
  },
  actionGrid: {
    flexDirection: 'row',
    gap: spacing.md,
  },
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
  infoCard: {
    paddingVertical: 4,
  },
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
  infoRowLast: {
    borderBottomWidth: 0,
  },
  infoLead: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flex: 1,
  },
  infoIcon: {
    width: 20,
    alignItems: 'center',
  },
  infoLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
  },
  infoValueSlot: {
    width: 108,
    alignItems: 'flex-end',
  },
  infoValueTag: {
    alignSelf: 'flex-end',
  },
  infoValue: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 13,
    fontWeight: '700',
    width: '100%',
    textAlign: 'right',
  },
  logoutButton: {
    marginTop: spacing.sm,
  },
});
