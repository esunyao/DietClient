import React, { useCallback, useState } from 'react';
import { ChevronDown } from 'lucide-react-native';
import { NativeModules, Pressable, StyleSheet, Text, View } from 'react-native';

import type { NumericWheelFieldProps } from './NumericWheelField';
import { colors, fonts, radii, spacing } from '../../theme/tokens';

type PickerResult = { action: 'cancel' | 'clear' | 'confirm'; value: number | null };
type NumericPickerModule = {
  open(initialValue: number, title: string, unit: string, minimum: number, maximum: number, step: number, allowClear: boolean): Promise<PickerResult>;
};

const picker = NativeModules.NumericPicker as NumericPickerModule | undefined;

function precision(step: number) {
  const text = String(step);
  return text.includes('.') ? text.length - text.indexOf('.') - 1 : 0;
}

export function NumericWheelField({ label, value, onChange, minimum, maximum, step, unit, placeholder }: NumericWheelFieldProps) {
  const [opening, setOpening] = useState(false);
  const number = Number(value);
  const selected = value.trim() !== '' && Number.isFinite(number) && number >= minimum && number <= maximum ? number : null;
  const digits = precision(step);
  const open = useCallback(async () => {
    if (!picker || opening) return;
    setOpening(true);
    try {
      const result = await picker.open(selected ?? minimum, `选择${label}`, unit, minimum, maximum, step, true);
      if (result.action === 'clear') onChange('');
      if (result.action === 'confirm' && result.value != null) onChange(result.value.toFixed(digits));
    } finally {
      setOpening(false);
    }
  }, [digits, label, maximum, minimum, onChange, opening, selected, step, unit]);

  const display = selected == null ? (placeholder ?? `请选择${label}`) : `${selected.toFixed(digits)}${unit ? ` ${unit}` : ''}`;
  return <View style={styles.field}>
    <Text style={styles.label}>{label}</Text>
    <Pressable accessibilityLabel={`选择${label}`} accessibilityRole="button" disabled={opening} onPress={open} style={[styles.control, opening && styles.disabled]}>
      <Text style={[styles.value, selected == null && styles.placeholder]}>{display}</Text>
      <ChevronDown color={colors.muted} size={18} />
    </Pressable>
  </View>;
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  control: { minHeight: 50, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: colors.line, borderRadius: radii.md, backgroundColor: colors.surface, paddingHorizontal: spacing.md },
  disabled: { opacity: 0.55 },
  value: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '700' },
  placeholder: { color: colors.placeholder, fontWeight: '500' },
});
