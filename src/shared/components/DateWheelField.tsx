import React from 'react';
import { StyleSheet, Text, TextInput, View } from 'react-native';

import { inputStyle } from './ui';
import { colors, fonts } from '../theme/tokens';

export type DateWheelMode = 'date' | 'datetime';

export function DateWheelField({ label, value, onChange, optional = false }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  optional?: boolean;
  mode?: DateWheelMode;
  minimumDate?: Date;
  maximumDate?: Date;
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        accessibilityLabel={label}
        onChangeText={onChange}
        placeholder={optional ? 'YYYY-MM-DD（选填）' : 'YYYY-MM-DD'}
        placeholderTextColor="#94A3B8"
        style={inputStyle}
        value={value}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
});
