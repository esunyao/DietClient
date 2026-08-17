import React from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { CheckCircle2, LoaderCircle, Trash2 } from 'lucide-react-native';

import { colors, fonts } from '../../../shared/theme/tokens';
import type { CaptureImageFile } from '../services/mealCapture';

export function CaptureImageGrid({ files, progress, onRemove }: { files: CaptureImageFile[]; progress: Record<string, number>; onRemove?: (uri: string) => void }) {
  if (!files.length) return null;
  return <View style={styles.grid}>{files.map(file => <View key={file.uri} style={styles.card}><Image source={{ uri: file.uri }} style={styles.image} /><View style={styles.status}>{progress[file.uri] === 100 ? <CheckCircle2 color={colors.green} size={15} /> : progress[file.uri] !== undefined ? <LoaderCircle color={colors.blue} size={15} /> : null}<Text numberOfLines={1} style={styles.text}>{progress[file.uri] === 100 ? '已确认' : progress[file.uri] !== undefined ? `上传 ${progress[file.uri]}%` : '待上传'}</Text></View>{onRemove ? <Pressable accessibilityLabel="移除图片" onPress={() => onRemove(file.uri)} style={styles.remove}><Trash2 color="#fff" size={14} /></Pressable> : null}</View>)}</View>;
}
const styles = StyleSheet.create({ grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 9 }, card: { width: 104, height: 126, borderRadius: 13, overflow: 'hidden', backgroundColor: '#EDF4FA' }, image: { width: '100%', height: 92 }, status: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 7, paddingVertical: 5 }, text: { flex: 1, color: colors.muted, fontFamily: fonts.body, fontSize: 10, fontWeight: '700' }, remove: { position: 'absolute', top: 6, right: 6, backgroundColor: 'rgba(23,35,54,0.72)', padding: 5, borderRadius: 13 } });
