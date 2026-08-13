import React from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';

import { inputStyle } from './ui';
import { colors, fonts } from '../theme/tokens';

export type NumericWheelFieldProps = {
  label: string;
  value: string;
  onChange: (value: string) => void;
  minimum: number;
  maximum: number;
  step: number;
  unit: string;
  placeholder?: string;
};

// Android 用同名 .native 文件替换为原生 NumberPicker；其他平台保留受控输入回退。
export function NumericWheelField({ label, value, onChange, placeholder }: NumericWheelFieldProps) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput accessibilityLabel={label} keyboardType="decimal-pad" onChangeText={onChange} placeholder={placeholder} placeholderTextColor="#94A3B8" style={inputStyle} value={value} />
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
});
