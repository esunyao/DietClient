import React, { useCallback, useState } from 'react';
import { ChevronDown, Scale } from 'lucide-react-native';
import { NativeModules, Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, fonts, radii, spacing } from '../theme/tokens';

type WeightPickerResult = { action: 'cancel' | 'clear' | 'confirm'; value: number | null };

type WeightPickerModule = {
  open(initialValue: number): Promise<WeightPickerResult>;
};

const picker = NativeModules.WeightPicker as WeightPickerModule | undefined;

function asWeight(value: string): number | null {
  const number = Number(value);
  return /^\d{1,3}(?:\.\d)?$/.test(value) && number >= 10 && number <= 500 ? number : null;
}

export function WeightWheelField({ label, value, onChange }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  const [opening, setOpening] = useState(false);
  const selected = asWeight(value);
  const open = useCallback(async () => {
    if (!picker || opening) return;
    setOpening(true);
    try {
      const result = await picker.open(selected ?? 60);
      if (result.action === 'clear') onChange('');
      if (result.action === 'confirm' && result.value != null) onChange(result.value.toFixed(1));
    } finally {
      setOpening(false);
    }
  }, [onChange, opening, selected]);

  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <Pressable accessibilityLabel={`选择${label}`} accessibilityRole="button" disabled={opening} onPress={open} style={[styles.control, opening && styles.controlDisabled]}>
        <View style={styles.valueGroup}>
          <Scale color={colors.blue} size={18} />
          <Text style={[styles.value, selected == null && styles.placeholder]}>{selected == null ? '请选择目标体重' : `${selected.toFixed(1)} kg`}</Text>
        </View>
        <ChevronDown color={colors.muted} size={18} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  control: { minHeight: 50, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: colors.line, borderRadius: radii.md, backgroundColor: '#FFFFFF', paddingHorizontal: spacing.md },
  controlDisabled: { opacity: 0.55 },
  valueGroup: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  value: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '700' },
  placeholder: { color: '#94A3B8', fontWeight: '500' },
});
