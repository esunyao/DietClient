import React, { useState } from 'react';
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { ShieldAlert, Trash2 } from 'lucide-react-native';

import { GlassSurface } from '../surfaces/GlassSurface';
import { colors, fonts, radii, spacing } from '../../theme/tokens';
import { durations, timing } from '../../animation/config';

export type DestructiveConfirmSheetProps = {
  visible: boolean;
  title: string;
  summary: string;
  detail?: string;
  onCancel: () => void;
  onConfirm: () => Promise<void> | void;
};

export function DestructiveConfirmSheet({
  visible,
  title,
  summary,
  detail = '删除后无法恢复，请确认是否继续。',
  onCancel,
  onConfirm,
}: DestructiveConfirmSheetProps) {
  const insets = useSafeAreaInsets();
  const [confirming, setConfirming] = useState(false);
  const [mounted, setMounted] = useState(visible);
  const translateY = useSharedValue(visible ? 0 : 160);
  const opacity = useSharedValue(visible ? 1 : 0);

  React.useEffect(() => {
    if (visible) {
      setMounted(true);
      translateY.value = withTiming(0, timing(durations.sheetIn));
      opacity.value = withTiming(1, timing(durations.sheetIn));
      return undefined;
    }
    if (!mounted) return undefined;
    translateY.value = withTiming(160, timing(durations.sheetOut));
    opacity.value = withTiming(0, timing(durations.sheetOut));
    const timer = setTimeout(() => setMounted(false), durations.sheetOut);
    return () => clearTimeout(timer);
  }, [mounted, opacity, translateY, visible]);

  const cardStyle = useAnimatedStyle(() => ({ transform: [{ translateY: translateY.value }] }));
  const backdropStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));

  if (!mounted) return null;

  const confirm = async () => {
    if (confirming) return;
    setConfirming(true);
    try {
      await onConfirm();
    } catch {
      // 由调用方展示错误；保留弹层让用户可以重试或取消。
      setConfirming(false);
    }
  };

  return (
    <Modal
      animationType="none"
      onRequestClose={onCancel}
      transparent
      visible={mounted}
      statusBarTranslucent
    >
      <View style={styles.root}>
        <Animated.View style={[StyleSheet.absoluteFill, backdropStyle]}>
          <Pressable accessibilityLabel="关闭删除确认" onPress={onCancel} style={styles.backdrop} />
        </Animated.View>
        <Animated.View style={[styles.cardWrap, { paddingBottom: Math.max(insets.bottom, spacing.md) }, cardStyle]}>
          <GlassSurface elevated variant="navigation" cornerRadius={radii.lg} style={styles.card}>
            <View style={styles.handle} />
            <View style={styles.iconWrap}><ShieldAlert color={colors.red} size={22} strokeWidth={2.2} /></View>
            <Text style={styles.title}>{title}</Text>
            <Text numberOfLines={2} style={styles.summary}>{summary}</Text>
            <Text style={styles.detail}>{detail}</Text>
            <View style={styles.actions}>
              <Pressable accessibilityRole="button" disabled={confirming} onPress={onCancel} style={[styles.action, styles.keepAction, confirming && styles.disabled]}>
                <Text style={styles.keepText}>保留记录</Text>
              </Pressable>
              <Pressable accessibilityRole="button" disabled={confirming} onPress={confirm} style={[styles.action, styles.deleteAction, confirming && styles.disabled]}>
                <Trash2 color={colors.inverse} size={16} />
                <Text style={styles.deleteText}>{confirming ? '正在删除…' : '删除记录'}</Text>
              </Pressable>
            </View>
          </GlassSurface>
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, justifyContent: 'flex-end' },
  backdrop: { flex: 1, backgroundColor: colors.scrim },
  cardWrap: { paddingHorizontal: spacing.md },
  card: { paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.lg },
  handle: { alignSelf: 'center', width: 34, height: 4, borderRadius: 2, backgroundColor: colors.line, marginBottom: spacing.md },
  iconWrap: { alignSelf: 'center', width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.redSoft, marginBottom: spacing.sm },
  title: { color: colors.ink, fontFamily: fonts.display, fontSize: 19, fontWeight: '800', textAlign: 'center' },
  summary: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '700', textAlign: 'center', marginTop: spacing.sm },
  detail: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, lineHeight: 18, textAlign: 'center', marginTop: spacing.xs },
  actions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.lg },
  action: { flex: 1, minHeight: 46, borderRadius: radii.md, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: 6 },
  keepAction: { backgroundColor: colors.blueSoft, borderWidth: 1, borderColor: colors.line },
  deleteAction: { backgroundColor: colors.red },
  keepText: { color: colors.blue, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' },
  deleteText: { color: colors.inverse, fontFamily: fonts.body, fontSize: 14, fontWeight: '800' },
  disabled: { opacity: 0.58 },
});
