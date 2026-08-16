import React, { useEffect, useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { Check, ChevronDown } from 'lucide-react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { colors, fonts, radii, spacing } from '../../theme/tokens';
import { GlassSurface } from '../surfaces/GlassSurface';

export type HealthPickerOption = { value: string; label: string; description?: string };

export function HealthPickerSheet({ visible, title, value, options, onCancel, onConfirm, children, confirmLabel = '确定选择' }: {
  visible: boolean;
  title: string;
  value: string;
  options?: HealthPickerOption[];
  onCancel: () => void;
  onConfirm: (value: string) => void;
  children?: React.ReactNode;
  confirmLabel?: string;
}) {
  const [draft, setDraft] = useState(value);
  const progress = useSharedValue(0);
  useEffect(() => { if (visible) { setDraft(value); progress.value = withTiming(1, { duration: 180, easing: Easing.out(Easing.cubic) }); } }, [progress, value, visible]);
  const panelStyle = useAnimatedStyle(() => ({ opacity: progress.value, transform: [{ translateY: (1 - progress.value) * 34 }] }));
  const close = () => { progress.value = withTiming(0, { duration: 120, easing: Easing.in(Easing.cubic) }); onCancel(); };
  return <Modal animationType="none" onRequestClose={close} transparent visible={visible}>
    <View style={styles.backdrop}>
      <Pressable accessibilityLabel="关闭选择" onPress={close} style={StyleSheet.absoluteFill} />
      <Animated.View style={[styles.animatedPanel, panelStyle]}>
        <GlassSurface variant="navigation" style={styles.panel}>
          <View style={styles.handle} />
          <View style={styles.heading}><View><Text style={styles.title}>{title}</Text><Text style={styles.subtitle}>选择最符合当前情况的一项</Text></View><Pressable onPress={close}><Text style={styles.cancel}>取消</Text></Pressable></View>
          {children ?? <View style={styles.options}>{options?.map(option => <Pressable key={option.value} onPress={() => setDraft(option.value)} style={[styles.option, draft === option.value && styles.optionActive]}><View style={styles.optionCopy}><Text style={[styles.optionText, draft === option.value && styles.optionTextActive]}>{option.label}</Text>{option.description ? <Text style={styles.optionDescription}>{option.description}</Text> : null}</View>{draft === option.value ? <View style={styles.check}><Check color="#FFFFFF" size={14} strokeWidth={3} /></View> : <View style={styles.emptyCheck} />}</Pressable>)}</View>}
          <Pressable accessibilityRole="button" onPress={() => onConfirm(draft)} style={styles.confirm}><Text style={styles.confirmText}>{confirmLabel}</Text></Pressable>
        </GlassSurface>
      </Animated.View>
    </View>
  </Modal>;
}

export function HealthSelectField({ label, value, options, onChange, placeholder = '请选择' }: { label: string; value: string; options: HealthPickerOption[]; onChange: (value: string) => void; placeholder?: string }) {
  const [open, setOpen] = useState(false);
  const selected = options.find(item => item.value === value);
  return <View style={styles.field}><Text style={styles.label}>{label}</Text><Pressable accessibilityLabel={`选择${label}`} accessibilityRole="button" onPress={() => setOpen(true)} style={styles.valueCard}><View style={styles.valueCopy}><Text style={[styles.value, !selected && styles.placeholder]}>{selected?.label ?? placeholder}</Text>{selected?.description ? <Text numberOfLines={1} style={styles.valueDescription}>{selected.description}</Text> : null}</View><ChevronDown color={colors.blue} size={19} /></Pressable><HealthPickerSheet onCancel={() => setOpen(false)} onConfirm={next => { onChange(next); setOpen(false); }} options={options} title={label} value={value} visible={open} /></View>;
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(15, 23, 42, 0.30)' },
  animatedPanel: { paddingHorizontal: spacing.sm, paddingBottom: spacing.sm },
  panel: { borderRadius: radii.lg, overflow: 'hidden', padding: spacing.lg, gap: spacing.md },
  handle: { alignSelf: 'center', width: 36, height: 4, borderRadius: 2, backgroundColor: '#C9D5E2' },
  heading: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' },
  title: { color: colors.ink, fontFamily: fonts.display, fontSize: 20, fontWeight: '800' },
  subtitle: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 3 },
  cancel: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, fontWeight: '700', padding: 4 },
  options: { gap: spacing.sm },
  option: { minHeight: 58, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderRadius: radii.md, paddingHorizontal: spacing.md, backgroundColor: 'rgba(241, 245, 249, 0.84)' },
  optionActive: { backgroundColor: '#EAF4FF', borderColor: '#A7D6FF', borderWidth: 1 },
  optionCopy: { flex: 1, minWidth: 0 },
  optionText: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '800' },
  optionTextActive: { color: colors.blue },
  optionDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 3 },
  check: { width: 22, height: 22, alignItems: 'center', justifyContent: 'center', borderRadius: 11, backgroundColor: colors.blue },
  emptyCheck: { width: 22, height: 22, borderRadius: 11, borderWidth: 1.5, borderColor: '#C9D5E2' },
  confirm: { minHeight: 50, alignItems: 'center', justifyContent: 'center', borderRadius: radii.md, backgroundColor: colors.blue },
  confirmText: { color: '#FFFFFF', fontFamily: fonts.body, fontSize: 15, fontWeight: '800' },
  field: { gap: 7 },
  label: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '700' },
  valueCard: { minHeight: 54, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm, borderRadius: radii.md, borderWidth: 1, borderColor: '#DCE7F1', backgroundColor: 'rgba(255,255,255,0.78)', paddingHorizontal: spacing.md },
  valueCopy: { flex: 1, minWidth: 0 },
  value: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '800' },
  placeholder: { color: '#94A3B8', fontWeight: '500' },
  valueDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, marginTop: 2 },
});
