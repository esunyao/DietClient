import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, fonts } from '../../../shared/theme/tokens';
import type { MealType } from '../api/nutriTypes';
import { mealTypeLabels } from '../services/mealCorrection';

export function MealTypeSegmentedControl({ value, onChange, includeAll = false }: { value: MealType | 'all'; onChange: (value: MealType | 'all') => void; includeAll?: boolean }) {
  const values: Array<MealType | 'all'> = includeAll ? ['all', 'breakfast', 'lunch', 'dinner', 'snack', 'other'] : ['breakfast', 'lunch', 'dinner', 'snack', 'other'];
  return <View style={styles.wrap}>{values.map(item => <Pressable key={item} accessibilityRole="button" onPress={() => onChange(item)} style={[styles.item, item === value && styles.active]}><Text style={[styles.text, item === value && styles.activeText]}>{item === 'all' ? '全部' : mealTypeLabels[item]}</Text></Pressable>)}</View>;
}

const styles = StyleSheet.create({
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 },
  item: { borderRadius: 16, borderWidth: 1, borderColor: colors.line, backgroundColor: '#FFFFFF', paddingHorizontal: 11, paddingVertical: 7 },
  active: { backgroundColor: 'rgba(0,113,227,0.1)', borderColor: 'rgba(0,113,227,0.35)' },
  text: { color: colors.muted, fontFamily: fonts.body, fontWeight: '700', fontSize: 12 },
  activeText: { color: colors.blue },
});
