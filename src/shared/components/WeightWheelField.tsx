import React from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';

import { inputStyle } from './ui';
import { colors, fonts } from '../theme/tokens';

export function WeightWheelField({ label, value, onChange }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput accessibilityLabel={label} keyboardType="decimal-pad" onChangeText={onChange} placeholder="10.0–500.0" placeholderTextColor="#94A3B8" style={inputStyle} value={value} />
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
});
