import React, { memo, useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import {
  ChevronRight,
  Ruler,
  Scale,
  ShieldAlert,
  Stethoscope,
  Target,
  Utensils,
} from 'lucide-react-native';
import type { ProfileStackParamList } from '../../../navigation/types';
import { getErrorMessage } from '../../../shared/api/client';
import { PressableScale } from '../../../shared/animation/PressableScale';
import {
  AppButton,
  AppScreen,
  GlassCard,
  ScreenHeader,
  SectionTitle,
} from '../../../shared/components';
import { scheduleIdleTask } from '../../../shared/perf/scheduleIdleTask';
import { colors, fonts, spacing } from '../../../shared/theme/tokens';
import type {
  Allergy,
  BodyMeasurement,
  DietaryRestriction,
  HealthGoal,
  MedicalCondition,
} from '../api/profileTypes';
import { useToast } from '../../../shared/components';
import { getCachedHealthRecords, getHealthRecords } from '../services/healthRecords';
type HealthProps = NativeStackScreenProps<ProfileStackParamList, 'HealthRecords'>;
type FormProps = NativeStackScreenProps<ProfileStackParamList, 'HealthRecordForm'>;
type Kind = FormProps['route']['params']['kind'];
type HealthData = {
  measurements: BodyMeasurement[];
  goals: HealthGoal[];
  allergies: Allergy[];
  conditions: MedicalCondition[];
  restrictions: DietaryRestriction[];
};
const emptyData: HealthData = {
  measurements: [],
  goals: [],
  allergies: [],
  conditions: [],
  restrictions: [],
};
const RecordSection = memo(function ({
  icon,
  title,
  detail,
  count,
  onPress,
}: {
  icon: React.ReactNode;
  title: string;
  detail: string;
  count: number;
  onPress: () => void;
}) {
  return (
    <PressableScale accessibilityRole="button" onPress={onPress} style={styles.recordSection}>
      <View style={styles.recordIcon}>{icon}</View>
      <View style={styles.recordCopy}>
        <Text style={styles.recordTitle}>{title}</Text>
        <Text style={styles.recordDetail}>{detail}</Text>
      </View>
      <View style={styles.count}>
        <Text style={styles.countText}>{count} 条</Text>
      </View>
      <ChevronRight color={colors.muted} size={18} />
    </PressableScale>
  );
});
export function HealthRecordsScreen({ navigation, route }: HealthProps) {
  const { show } = useToast();
  const [data, setData] = useState<HealthData>(emptyData);
  const [loading, setLoading] = useState(true);
  const load = useCallback(
    async (force = false) => {
      const cached = !force ? getCachedHealthRecords() : null;
      if (cached) {
        setData(cached);
        setLoading(false);
        return;
      }
      setLoading(true);
      try {
        setData(await getHealthRecords(force));
      } catch (error) {
        show(getErrorMessage(error), 'error');
      } finally {
        setLoading(false);
      }
    },
    [show],
  );
  useFocusEffect(
    useCallback(() => {
      const cancel = scheduleIdleTask(() => {
        load(true).catch(() => undefined);
      });
      return cancel;
    }, [load]),
  );
  const open = (kind: Kind) =>
    navigation.navigate('HealthRecordForm', {
      kind,
    });
  return (
    <AppScreen
      header={
        <ScreenHeader
          title="健康档案"
          subtitle="集中管理你的健康资料"
          onBack={() => navigation.goBack()}
        />
      }
    >
      <GlassCard elevated={false} variant="soft" style={styles.overview}>
        <Text style={styles.overviewTitle}>
          {route.params?.onboarding ? '基础档案已保存' : '健康资料'}{' '}
        </Text>
        <Text style={styles.overviewText}>
          {route.params?.onboarding
            ? '接下来可补充身体数据与健康记录，也可以稍后再填。'
            : '每一项都可以随时新增、修改或删除。'}
        </Text>
        {route.params?.onboarding ? (
          <AppButton
            label="暂不添加，进入我的页面"
            variant="secondary"
            onPress={() => navigation.replace('ProfileMain')}
          />
        ) : null}
      </GlassCard>
      <SectionTitle title="基础与测量" />
      <GlassCard elevated={false} variant="soft" style={styles.sectionCard}>
        <RecordSection
          icon={<Ruler color={colors.blue} size={19} />}
          title="基础档案"
          detail="生日、身高、活动与饮水目标"
          count={1}
          onPress={() => navigation.navigate('EditProfile')}
        />
        <RecordSection
          icon={<Scale color={colors.blue} size={19} />}
          title="身体测量"
          detail="体重、体脂、围度、血压与心率"
          count={data.measurements.length}
          onPress={() => open('measurement')}
        />
      </GlassCard>
      <SectionTitle title="健康计划与提醒" />
      <GlassCard elevated={false} variant="soft" style={styles.sectionCard}>
        <RecordSection
          icon={<Target color={colors.green} size={19} />}
          title="健康目标"
          detail="体重、体脂与改善方向"
          count={data.goals.length}
          onPress={() => open('goal')}
        />
        <RecordSection
          icon={<ShieldAlert color={colors.amber} size={19} />}
          title="过敏记录"
          detail="过敏原、严重程度与反应"
          count={data.allergies.length}
          onPress={() => open('allergy')}
        />
        <RecordSection
          icon={<Stethoscope color={colors.red} size={19} />}
          title="疾病记录"
          detail="诊断状态、日期与备注"
          count={data.conditions.length}
          onPress={() => open('condition')}
        />
        <RecordSection
          icon={<Utensils color={colors.blue} size={19} />}
          title="饮食限制"
          detail="限制类别、生效日期与备注"
          count={data.restrictions.length}
          onPress={() => open('restriction')}
        />
      </GlassCard>
      {loading ? <Text style={styles.loading}>正在更新健康资料…</Text> : null}
    </AppScreen>
  );
}
const styles = StyleSheet.create({
  overview: {
    gap: spacing.sm,
  },
  overviewTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
  },
  overviewText: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    lineHeight: 19,
  },
  sectionCard: {
    paddingVertical: 0,
  },
  recordSection: {
    minHeight: 70,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderBottomColor: colors.line,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  recordIcon: {
    width: 34,
    height: 34,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F1F7FD',
  },
  recordCopy: {
    flex: 1,
  },
  recordTitle: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontSize: 14,
    fontWeight: '800',
  },
  recordDetail: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    marginTop: 3,
  },
  count: {
    minWidth: 38,
    alignItems: 'flex-end',
  },
  countText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontSize: 12,
    fontWeight: '800',
  },
  loading: {
    color: colors.muted,
    fontFamily: fonts.body,
    textAlign: 'center',
    fontSize: 12,
  },
});
