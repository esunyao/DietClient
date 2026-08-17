import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { GlassCard } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import type { NutrientValue } from '../api/nutriTypes';

const primaryCodes = ['ENERGY_KCAL', 'PROTEIN', 'CARBOHYDRATE', 'FAT'];

function amount(value: number): string { return Number.isInteger(value) ? String(value) : value.toFixed(1).replace(/\.0$/, ''); }

export function NutrientMetricGrid({ nutrients }: { nutrients: NutrientValue[] }) {
  const metrics = primaryCodes.map(code => nutrients.find(item => item.nutrientCode === code) ?? { nutrientCode: code, nutrientName: code === 'ENERGY_KCAL' ? '能量' : code === 'PROTEIN' ? '蛋白质' : code === 'CARBOHYDRATE' ? '碳水' : '脂肪', amount: 0, unit: code === 'ENERGY_KCAL' ? 'kcal' : 'g' });
  return <View style={styles.grid}>{metrics.map(item => <GlassCard key={item.nutrientCode} style={styles.card}><Text style={styles.label}>{item.nutrientName}</Text><Text style={styles.value}>{amount(item.amount)} <Text style={styles.unit}>{item.unit}</Text></Text></GlassCard>)}</View>;
}

export function NutrientList({ nutrients }: { nutrients: NutrientValue[] }) {
  return <View style={styles.list}>{nutrients.map(item => <View key={item.nutrientCode} style={styles.row}><Text style={styles.rowLabel}>{item.nutrientName}</Text><Text style={styles.rowValue}>{amount(item.amount)} {item.unit}</Text></View>)}</View>;
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 9 }, card: { width: '47.9%', padding: 12, gap: 5 },
  label: { color: colors.muted, fontFamily: fonts.body, fontWeight: '700', fontSize: 12 }, value: { color: colors.ink, fontFamily: fonts.body, fontWeight: '800', fontSize: 19 }, unit: { color: colors.muted, fontSize: 11 },
  list: { gap: 1 }, row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 10, borderBottomColor: colors.line, borderBottomWidth: StyleSheet.hairlineWidth }, rowLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 14 }, rowValue: { color: colors.blue, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' },
});
