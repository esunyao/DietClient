import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import Slider from '@react-native-community/slider';
import { ChevronRight } from 'lucide-react-native';

import { colors, fonts, radii, spacing } from '../../theme/tokens';
import {
  isPercentageInput,
  normalizePercentageInput,
  PERCENTAGE_VALIDATION_MESSAGE,
  percentageFromSlider,
} from '../../validation/percentage';
import { HealthPickerSheet } from '../overlays/HealthPickerSheet';

type PercentageSliderFieldProps = {
  label: string;
  value: string;
  onChange: (value: string) => void;
  allowClear: boolean;
};

export function PercentageSliderField({ label, value, onChange, allowClear }: PercentageSliderFieldProps) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState(value);
  const [error, setError] = useState<string | null>(null);
  const normalizedValue = normalizePercentageInput(value);
  const normalizedDraft = normalizePercentageInput(draft);
  const sliderValue = normalizedDraft == null ? 0 : Number(normalizedDraft);

  const openPicker = () => {
    setDraft(normalizedValue ?? '');
    setError(null);
    setOpen(true);
  };

  const updateInput = (next: string) => {
    if (!isPercentageInput(next)) {
      setError(PERCENTAGE_VALIDATION_MESSAGE);
      return;
    }
    setDraft(next);
    setError(null);
  };

  const confirm = () => {
    if (error) return;
    if (!draft) {
      if (allowClear) {
        onChange('');
        setError(null);
        setOpen(false);
        return;
      }
      setError('已有体脂率不能清空，请输入新的数值');
      return;
    }

    const normalized = normalizePercentageInput(draft);
    if (normalized == null) {
      setError(PERCENTAGE_VALIDATION_MESSAGE);
      return;
    }

    onChange(normalized);
    setError(null);
    setOpen(false);
  };

  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label} (%)</Text>
      <Pressable
        accessibilityLabel={`设置${label}`}
        accessibilityRole="button"
        onPress={openPicker}
        style={styles.valueCard}
      >
        <Text style={[styles.value, normalizedValue == null && styles.placeholder]}>
          {normalizedValue == null ? '暂不设置' : `${normalizedValue}%`}
        </Text>
        <ChevronRight color={colors.blue} size={18} />
      </Pressable>

      <HealthPickerSheet
        confirmLabel="保存体脂率"
        onCancel={() => setOpen(false)}
        onConfirm={confirm}
        title={label}
        value={value}
        visible={open}
      >
        <View style={styles.sheetContent}>
          <Text accessibilityLiveRegion="polite" style={styles.metric}>
            {normalizedDraft == null ? '暂不设置' : `${normalizedDraft}%`}
          </Text>
          <Slider
            accessibilityLabel={`${label}滑块`}
            maximumTrackTintColor="#D9E4EF"
            maximumValue={100}
            minimumTrackTintColor={colors.blue}
            minimumValue={0}
            onValueChange={next => {
              setDraft(percentageFromSlider(next));
              setError(null);
            }}
            step={0.1}
            thumbTintColor={colors.blue}
            value={sliderValue}
          />
          <View style={[styles.inputShell, error && styles.inputShellError]}>
            <TextInput
              accessibilityLabel={`${label}精确输入`}
              keyboardType="decimal-pad"
              maxLength={5}
              onChangeText={updateInput}
              placeholder="0.0"
              placeholderTextColor="#94A3B8"
              selectionColor={colors.blue}
              style={styles.input}
              value={draft}
            />
            <Text style={styles.suffix}>%</Text>
          </View>
          <Text style={[styles.hint, error && styles.error]}>{error ?? '可拖动滑块，或输入 0–100 的精确数值'}</Text>
          {allowClear ? (
            <Pressable accessibilityRole="button" onPress={() => { setDraft(''); setError(null); }} style={styles.clear}>
              <Text style={styles.clearText}>暂不设置体脂率</Text>
            </Pressable>
          ) : null}
        </View>
      </HealthPickerSheet>
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  valueCard: { minHeight: 54, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderWidth: 1, borderColor: '#DCE7F1', borderRadius: radii.md, backgroundColor: 'rgba(255,255,255,0.78)', paddingHorizontal: spacing.md },
  value: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '800' },
  placeholder: { color: '#94A3B8', fontWeight: '500' },
  sheetContent: { gap: spacing.md, paddingVertical: spacing.sm },
  metric: { color: colors.blue, fontFamily: fonts.display, fontSize: 28, fontWeight: '800', textAlign: 'center' },
  inputShell: { minHeight: 54, flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderColor: '#DCE7F1', borderRadius: radii.md, backgroundColor: 'rgba(255,255,255,0.88)', paddingHorizontal: spacing.md },
  inputShellError: { borderColor: colors.red, backgroundColor: colors.redSoft },
  input: { flex: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 18, fontWeight: '800', paddingVertical: 0 },
  suffix: { color: colors.muted, fontFamily: fonts.body, fontSize: 16, fontWeight: '800' },
  hint: { minHeight: 17, color: colors.muted, fontFamily: fonts.body, fontSize: 11, lineHeight: 16 },
  error: { color: colors.red },
  clear: { alignSelf: 'center', paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  clearText: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
});
