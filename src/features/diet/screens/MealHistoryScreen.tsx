import React, { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

import type { DietStackParamList } from '../../../navigation/types';
import { PageShell } from '../../../navigation/components/PageShell';
import { getErrorMessage } from '../../../shared/api/client';
import {
  AppButton,
  DateWheelField,
  EmptyState,
  GlassCard,
  SectionTitle,
  inputStyle,
  useToast,
} from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import { MealHistoryRow, MealTypeSegmentedControl } from '../components';
import { nutriApi } from '../api/nutriApi';
import type { MealHistoryItem, MealType } from '../api/nutriTypes';
import { localDateFromDate } from '../services/mealCapture';

type Props = NativeStackScreenProps<DietStackParamList, 'MealHistory'>;
function daysBefore(days: number) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return localDateFromDate(date);
}

export function MealHistoryScreen({ navigation }: Props) {
  const { show } = useToast();
  const [dateFrom, setDateFrom] = useState(daysBefore(30));
  const [dateTo, setDateTo] = useState(localDateFromDate());
  const [mealType, setMealType] = useState<MealType | 'all'>('all');
  const [q, setQ] = useState('');
  const [items, setItems] = useState<MealHistoryItem[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const load = useCallback(
    async (next = 1, append = false) => {
      if (dateFrom > dateTo) return show('结束日期不能早于开始日期。', 'error');
      setLoading(true);
      try {
        const result = await nutriApi.listMeals({
          dateFrom,
          dateTo,
          mealType: mealType === 'all' ? undefined : mealType,
          q: q.trim() || undefined,
          page: next,
        });
        setItems(current => (append ? [...current, ...result.items] : result.items));
        setPage(next);
        setTotal(result.total);
      } catch (error) {
        show(getErrorMessage(error), 'error');
      } finally {
        setLoading(false);
      }
    },
    [dateFrom, dateTo, mealType, q, show],
  );
  useEffect(() => {
    load();
  }, [load]);
  return (
    <PageShell pageId="mealHistory" onBack={() => navigation.goBack()}>
      <GlassCard style={styles.filters}>
        <View style={styles.dates}>
          <DateWheelField label="开始日期" value={dateFrom} onChange={setDateFrom} />
          <DateWheelField label="结束日期" value={dateTo} onChange={setDateTo} />
        </View>
        <Text style={styles.label}>餐次</Text>
        <MealTypeSegmentedControl
          value={mealType}
          onChange={value => setMealType(value as MealType | 'all')}
          includeAll
        />
        <Text style={styles.label}>备注或菜品关键词</Text>
        <TextInput
          accessibilityLabel="备注或菜品关键词"
          value={q}
          onChangeText={setQ}
          placeholder="搜索备注或菜品名称"
          placeholderTextColor="#94A3B8"
          style={inputStyle}
        />
        <AppButton label="应用筛选" variant="secondary" onPress={() => load()} />
      </GlassCard>
      <SectionTitle title="历史记录" detail={loading ? '正在加载…' : `共 ${total} 条`} />
      {items.length ? (
        <View style={styles.list}>
          {items.map(item => (
            <MealHistoryRow
              key={item.mealId}
              meal={item}
              onPress={() => navigation.navigate('MealDetail', { mealId: item.mealId })}
            />
          ))}
          {items.length < total ? (
            <AppButton
              label="加载更多"
              variant="secondary"
              loading={loading}
              onPress={() => load(page + 1, true)}
            />
          ) : null}
        </View>
      ) : (
        <EmptyState title="没有匹配的饮食记录" description="调整日期、餐次或关键词后再试。" />
      )}
    </PageShell>
  );
}
const styles = StyleSheet.create({
  filters: { gap: 11 },
  dates: { flexDirection: 'row', alignItems: 'flex-start', gap: 10, minWidth: 0 },
  label: {
    color: colors.ink,
    fontFamily: fonts.body,
    fontWeight: '700',
    fontSize: 13,
    marginTop: 2,
  },
  list: { gap: 9 },
});
