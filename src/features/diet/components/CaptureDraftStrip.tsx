import React from 'react';
import { Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Clock3, Plus, Trash2 } from 'lucide-react-native';

import { colors, fonts } from '../../../shared/theme/tokens';
import type { CaptureDraftSummary } from '../api/nutriTypes';

interface Props {
  drafts: CaptureDraftSummary[];
  selectedId: string | null;
  maxDrafts: number | null;
  disabled?: boolean;
  onSelect: (id: string) => void;
  onDelete: (id: string) => void;
  onNew: () => void;
}

function remaining(expiresAt: string): string {
  const minutes = Math.max(0, Math.round((new Date(expiresAt).getTime() - Date.now()) / 60000));
  if (minutes < 60) return `剩余 ${minutes} 分钟`;
  return `剩余 ${Math.ceil(minutes / 60)} 小时`;
}

export function CaptureDraftStrip({
  drafts,
  selectedId,
  maxDrafts,
  disabled = false,
  onSelect,
  onDelete,
  onNew,
}: Props) {
  if (drafts.length === 0) return null;

  return (
    <View style={styles.wrap}>
      <View style={styles.heading}>
        <Text style={styles.title}>未提交草稿</Text>
        <Text style={styles.count}>
          {drafts.length}/{maxDrafts ?? '…'}
        </Text>
      </View>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.row}
      >
        {drafts.map(draft => {
          const image = draft.images[0];
          return (
            <Pressable
              key={draft.captureSessionId}
              disabled={disabled}
              onPress={() => onSelect(draft.captureSessionId)}
              style={[
                styles.card,
                selectedId === draft.captureSessionId && styles.selected,
                disabled && styles.disabled,
              ]}
            >
              <Pressable
                accessibilityLabel="删除草稿"
                accessibilityRole="button"
                disabled={disabled}
                hitSlop={6}
                onPress={event => {
                  event.stopPropagation();
                  onDelete(draft.captureSessionId);
                }}
                style={styles.deleteButton}
              >
                <Trash2 color={colors.ink} size={14} />
              </Pressable>
              {image?.previewUrl ? (
                <Image source={{ uri: image.previewUrl }} style={styles.thumb} />
              ) : (
                <View style={styles.placeholder}>
                  <Text style={styles.placeholderText}>餐盘</Text>
                </View>
              )}
              <View style={styles.meta}>
                <Text style={styles.metaText}>{draft.confirmedImageCount} 张图片</Text>
                <View style={styles.expiry}>
                  <Clock3 size={11} color={colors.muted} />
                  <Text style={styles.metaText}>{remaining(draft.expiresAt)}</Text>
                </View>
              </View>
            </Pressable>
          );
        })}
        <Pressable
          accessibilityRole="button"
          disabled={disabled || maxDrafts === null || drafts.length >= maxDrafts}
          onPress={onNew}
          style={[
            styles.newCard,
            (disabled || maxDrafts === null || drafts.length >= maxDrafts) && styles.disabled,
          ]}
        >
          <Plus color={colors.blue} size={20} />
          <Text style={styles.newText}>新建一餐</Text>
        </Pressable>
      </ScrollView>
      {maxDrafts !== null && drafts.length >= maxDrafts ? (
        <Text style={styles.hint}>草稿已达上限，请提交或取消一份后再新建。</Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: 8 },
  heading: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  title: { color: colors.ink, fontFamily: fonts.body, fontSize: 15, fontWeight: '800' },
  count: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  row: { gap: 9, paddingVertical: 2 },
  card: {
    width: 130,
    padding: 7,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.surface,
    gap: 6,
    position: 'relative',
  },
  selected: { borderColor: colors.blue, borderWidth: 2 },
  deleteButton: {
    position: 'absolute',
    top: 7,
    right: 7,
    zIndex: 1,
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface,
  },
  thumb: { width: '100%', height: 72, borderRadius: 9, backgroundColor: colors.surfaceMuted },
  placeholder: {
    width: '100%',
    height: 72,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceMuted,
  },
  placeholderText: { color: colors.muted, fontFamily: fonts.body, fontSize: 12 },
  meta: { gap: 2 },
  expiry: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  metaText: { color: colors.muted, fontFamily: fonts.body, fontSize: 10 },
  newCard: {
    width: 130,
    height: 108,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.blueSoft,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 5,
  },
  newText: { color: colors.blue, fontFamily: fonts.body, fontSize: 12, fontWeight: '800' },
  disabled: { opacity: 0.48 },
  hint: { color: colors.muted, fontFamily: fonts.body, fontSize: 11 },
});
