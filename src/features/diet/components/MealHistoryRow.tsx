import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { ChevronRight } from 'lucide-react-native';

import { GlassCard } from '../../../shared/components';
import { colors, fonts } from '../../../shared/theme/tokens';
import type { MealHistoryItem } from '../api/nutriTypes';
import { mealTypeLabels } from '../services/mealCorrection';

const emoji: Record<MealHistoryItem['mealType'], string> = { breakfast: '🥣', lunch: '🥗', dinner: '🍲', snack: '🍎', other: '🍽️' };

export function MealHistoryRow({ meal, onPress }: { meal: MealHistoryItem; onPress: () => void }) {
  const energy = meal.nutrients.find(item => item.nutrientCode === 'ENERGY_KCAL');
  return <Pressable accessibilityRole="button" onPress={onPress}><GlassCard style={styles.card}><Text style={styles.emoji}>{emoji[meal.mealType]}</Text><View style={styles.copy}><Text numberOfLines={1} style={styles.title}>{meal.notes || mealTypeLabels[meal.mealType]}</Text><Text style={styles.meta}>{new Date(meal.consumedAt).toLocaleString([], { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })} · {energy?.amount ?? 0} kcal</Text></View><ChevronRight color={colors.muted} size={17} /></GlassCard></Pressable>;
}

const styles = StyleSheet.create({ card: { flexDirection: 'row', alignItems: 'center', gap: 11, padding: 13 }, emoji: { fontSize: 26 }, copy: { flex: 1, gap: 4 }, title: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '800' }, meta: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 } });
