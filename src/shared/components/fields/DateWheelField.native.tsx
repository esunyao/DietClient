import React, { useEffect, useMemo, useState } from 'react';
import { CalendarDays, X } from 'lucide-react-native';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import DatePicker from 'react-native-date-picker';

import type { DateWheelMode } from './DateWheelField';
import { HealthPickerSheet } from '../overlays/HealthPickerSheet';
import { colors, fonts, radii, spacing } from '../../theme/tokens';

function pad(value: number) {
  return String(value).padStart(2, '0');
}

function toPickerDate(value: string): Date {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [year, month, day] = value.split('-').map(Number);
    return new Date(year, month - 1, day);
  }
  const parsed = value ? new Date(value) : new Date();
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}

function formatDisplay(value: string, mode: DateWheelMode): string {
  const date = toPickerDate(value);
  const datePart = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
  return mode === 'datetime'
    ? `${datePart} ${pad(date.getHours())}:${pad(date.getMinutes())}`
    : datePart;
}

function serialize(date: Date, mode: DateWheelMode): string {
  if (mode === 'datetime') return date.toISOString();
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function DateWheelField({
  label,
  value,
  onChange,
  optional = false,
  mode = 'date',
  minimumDate,
  maximumDate,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  optional?: boolean;
  mode?: DateWheelMode;
  minimumDate?: Date;
  maximumDate?: Date;
}) {
  const [open, setOpen] = useState(false);
  const selectedDate = useMemo(() => toPickerDate(value), [value]);
  const [draft, setDraft] = useState(selectedDate);
  useEffect(() => {
    if (open) setDraft(selectedDate);
  }, [open, selectedDate]);

  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.controlRow}>
        <Pressable
          accessibilityLabel={`选择${label}`}
          onPress={() => setOpen(true)}
          style={styles.control}
        >
          <Text numberOfLines={1} style={[styles.value, !value && styles.placeholder]}>
            {value ? formatDisplay(value, mode) : '请选择日期'}
          </Text>
          <CalendarDays color={colors.blue} size={18} />
        </Pressable>
        {optional && value ? (
          <Pressable
            accessibilityLabel={`清除${label}`}
            hitSlop={8}
            onPress={() => onChange('')}
            style={styles.clear}
          >
            <X color={colors.muted} size={16} />
            <Text style={styles.clearText}>清除</Text>
          </Pressable>
        ) : null}
      </View>
      <HealthPickerSheet
        onCancel={() => setOpen(false)}
        onConfirm={() => {
          onChange(serialize(draft, mode));
          setOpen(false);
        }}
        title={label}
        value={value}
        visible={open}
      >
        <View style={styles.pickerWrap}>
          <DatePicker
            date={draft}
            is24hourSource="locale"
            locale="zh-CN"
            maximumDate={maximumDate}
            minimumDate={minimumDate}
            mode={mode}
            onDateChange={setDraft}
            theme="light"
          />
        </View>
      </HealthPickerSheet>
    </View>
  );
}

const styles = StyleSheet.create({
  field: { flex: 1, minWidth: 0, gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  controlRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  control: {
    minHeight: 50,
    minWidth: 0,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: radii.md,
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.md,
  },
  value: { flexShrink: 1, color: colors.ink, fontFamily: fonts.body, fontSize: 15 },
  placeholder: { color: colors.placeholder },
  clear: { flexDirection: 'row', alignItems: 'center', gap: 3, paddingVertical: spacing.sm },
  clearText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, fontWeight: '700' },
  pickerWrap: { alignItems: 'center', minHeight: 208 },
});
