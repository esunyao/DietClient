import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ArrowLeft, Camera, Sparkles, Utensils } from 'lucide-react-native';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';

import { colors, fonts, radii, spacing } from '../theme/tokens';
import { GlassSurface } from './GlassSurface';

export function AppScreen({ children, scroll = true, contentStyle }: {
  children: React.ReactNode;
  scroll?: boolean;
  contentStyle?: StyleProp<ViewStyle>;
}) {
  const content = scroll ? (
    <ScrollView contentContainerStyle={[styles.scrollContent, contentStyle]} showsVerticalScrollIndicator={false}>
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.fill, contentStyle]}>{children}</View>
  );

  return (
    <SafeAreaView edges={['top']} style={styles.screen}>
      <View pointerEvents="none" style={styles.canvasGlowOne} />
      <View pointerEvents="none" style={styles.canvasGlowTwo} />
      {content}
    </SafeAreaView>
  );
}

export function GlassCard({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <GlassSurface style={[styles.card, style]}>{children}</GlassSurface>;
}

export function ScreenHeader({ title, subtitle, onBack, action }: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  action?: React.ReactNode;
}) {
  return (
    <GlassSurface style={styles.header} intensity={42}>
      {onBack ? (
        <Pressable accessibilityLabel="返回" hitSlop={10} onPress={onBack} style={styles.backButton}>
          <ArrowLeft color={colors.ink} size={20} />
        </Pressable>
      ) : null}
      <View style={styles.headerText}>
        <Text style={styles.headerTitle}>{title}</Text>
        {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
      </View>
      {action ? <View style={styles.headerAction}>{action}</View> : null}
    </GlassSurface>
  );
}

export function AppButton({ label, onPress, loading, disabled, variant = 'primary', style }: {
  label: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  variant?: 'primary' | 'secondary' | 'danger';
  style?: StyleProp<ViewStyle>;
}) {
  const isDisabled = Boolean(disabled || loading);
  return (
    <Pressable
      accessibilityRole="button"
      disabled={isDisabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        variant === 'secondary' && styles.buttonSecondary,
        variant === 'danger' && styles.buttonDanger,
        isDisabled && styles.buttonDisabled,
        pressed && !isDisabled && styles.buttonPressed,
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={variant === 'secondary' ? colors.blue : '#FFFFFF'} size="small" /> : null}
      <Text style={[styles.buttonText, variant === 'secondary' && styles.buttonSecondaryText]}>{label}</Text>
    </Pressable>
  );
}

export function SectionTitle({ title, detail, action }: { title: string; detail?: string; action?: React.ReactNode }) {
  return (
    <View style={styles.sectionTitleRow}>
      <View style={styles.sectionTitleBlock}>
        <Text style={styles.sectionTitle}>{title}</Text>
        {detail ? <Text style={styles.sectionDetail}>{detail}</Text> : null}
      </View>
      {action}
    </View>
  );
}

export function Tag({ label, tone = 'blue' }: { label: string; tone?: 'blue' | 'green' | 'amber' | 'red' | 'plain' }) {
  return (
    <View style={[styles.tag, tone === 'green' && styles.tagGreen, tone === 'amber' && styles.tagAmber, tone === 'red' && styles.tagRed, tone === 'plain' && styles.tagPlain]}>
      <Text style={[styles.tagText, tone === 'green' && styles.tagGreenText, tone === 'amber' && styles.tagAmberText, tone === 'red' && styles.tagRedText, tone === 'plain' && styles.tagPlainText]}>{label}</Text>
    </View>
  );
}

export function MetricProgress({ label, value, color = colors.blue, rightLabel }: {
  label: string;
  value: number;
  color?: string;
  rightLabel?: string;
}) {
  const safeValue = Math.max(0, Math.min(value, 100));
  return (
    <View style={styles.metric}>
      <View style={styles.metricHead}>
        <Text style={styles.metricLabel}>{label}</Text>
        <Text style={styles.metricValue}>{rightLabel || `${safeValue}%`}</Text>
      </View>
      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${safeValue}%`, backgroundColor: color }]} />
      </View>
    </View>
  );
}

/** 首页与评分页的标志性“营养轨道”，以原型评分环转化成跨端 SVG。 */
export function ScoreRing({ score, size = 104, caption = '综合评分' }: { score: number; size?: number; caption?: string }) {
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const progress = Math.max(0, Math.min(score, 100));
  const containerStyle = { width: size, height: size, alignItems: 'center' as const, justifyContent: 'center' as const };

  return (
    <View style={containerStyle}>
      <Svg width={size} height={size} viewBox="0 0 100 100" style={styles.ringSvg}>
        <Defs>
          <LinearGradient id="nutritionOrbit" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={colors.blue} />
            <Stop offset="1" stopColor={colors.green} />
          </LinearGradient>
        </Defs>
        <Circle cx="50" cy="50" r={radius} stroke="#DDEAF7" strokeWidth="7" fill="none" />
        <Circle
          cx="50"
          cy="50"
          r={radius}
          stroke="url(#nutritionOrbit)"
          strokeWidth="7"
          fill="none"
          strokeLinecap="round"
          strokeDasharray={`${circumference} ${circumference}`}
          strokeDashoffset={circumference - (progress / 100) * circumference}
          transform="rotate(-90 50 50)"
        />
      </Svg>
      <View style={styles.ringCenter}>
        <Text style={styles.ringNumber}>{score}</Text>
        <Text style={styles.ringCaption}>{caption}</Text>
      </View>
    </View>
  );
}

export function LogoMark({ size = 62 }: { size?: number }) {
  const containerStyle = { width: size, height: size, alignItems: 'center' as const, justifyContent: 'center' as const };

  return (
    <View style={containerStyle}>
      <Svg width={size} height={size} viewBox="0 0 64 64">
        <Defs>
          <LinearGradient id="brandGradient" x1="2" y1="4" x2="62" y2="60">
            <Stop offset="0" stopColor={colors.blue} />
            <Stop offset="1" stopColor={colors.green} />
          </LinearGradient>
        </Defs>
        <Circle cx="32" cy="32" r="30" fill="url(#brandGradient)" />
        <Circle cx="48" cy="16" r="7" fill="rgba(255,255,255,0.24)" />
      </Svg>
      <View style={styles.logoIcon}><Utensils size={size * 0.38} color="#FFFFFF" strokeWidth={2.4} /></View>
    </View>
  );
}

export function Avatar({
  name,
  avatarUrl,
  size = 54,
  onPress,
  showEditBadge = false,
  onImageError,
}: {
  name: string;
  avatarUrl?: string | null;
  size?: number;
  onPress?: () => void;
  showEditBadge?: boolean;
  onImageError?: () => void;
}) {
  const initial = name.trim().slice(0, 1) || '你';
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  const imageVisible = Boolean(avatarUrl && avatarUrl !== failedUrl);

  useEffect(() => setFailedUrl(null), [avatarUrl]);

  const content = (
    <>
      <View style={[styles.avatar, { width: size, height: size, borderRadius: size / 2 }]}>
        <Svg width={size} height={size} viewBox="0 0 100 100" style={StyleSheet.absoluteFill}>
          <Defs>
            <LinearGradient id="avatarGradient" x1="0" y1="0" x2="1" y2="1">
              <Stop offset="0" stopColor={colors.blue} />
              <Stop offset="1" stopColor={colors.green} />
            </LinearGradient>
          </Defs>
          <Circle cx="50" cy="50" r="50" fill="url(#avatarGradient)" />
          <Circle cx="72" cy="24" r="18" fill="rgba(255,255,255,0.14)" />
        </Svg>
        <Text style={[styles.avatarText, { fontSize: size * 0.36 }]}>{initial}</Text>
      </View>
      {imageVisible ? (
        <Image
          accessibilityLabel={`${name}的头像`}
          onError={() => {
            setFailedUrl(avatarUrl || null);
            onImageError?.();
          }}
          source={{ uri: avatarUrl || undefined }}
          style={[styles.avatarImage, { width: size, height: size, borderRadius: size / 2 }]}
        />
      ) : null}
      {showEditBadge ? <View style={styles.avatarEditBadge}><Camera color="#FFFFFF" size={Math.max(12, size * 0.19)} /></View> : null}
    </>
  );

  return (
    <View style={[styles.avatarWrap, { width: size, height: size }]}>
      {onPress ? <Pressable accessibilityRole="button" accessibilityLabel="更换头像" onPress={onPress} style={styles.avatarPressable}>{content}</Pressable> : content}
    </View>
  );
}

export function EmptyState({ title, description, action }: { title: string; description: string; action?: React.ReactNode }) {
  return (
    <GlassCard style={styles.empty}>
      <View style={styles.emptyIcon}><Sparkles color={colors.blue} size={22} /></View>
      <Text style={styles.emptyTitle}>{title}</Text>
      <Text style={styles.emptyDescription}>{description}</Text>
      {action ? <View style={styles.emptyAction}>{action}</View> : null}
    </GlassCard>
  );
}

export const inputStyle: TextStyle = {
  minHeight: 50,
  borderWidth: 1,
  borderColor: colors.line,
  borderRadius: radii.md,
  backgroundColor: '#FFFFFF',
  color: colors.ink,
  fontFamily: fonts.body,
  fontSize: 15,
  paddingHorizontal: spacing.md,
};

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.canvas, overflow: 'hidden' },
  fill: { flex: 1 },
  scrollContent: { zIndex: 1, paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: 116, gap: spacing.lg },
  canvasGlowOne: { position: 'absolute', width: 250, height: 250, borderRadius: 125, top: -120, right: -90, backgroundColor: 'rgba(0,113,227,0.11)' },
  canvasGlowTwo: { position: 'absolute', width: 210, height: 210, borderRadius: 105, bottom: 100, left: -110, backgroundColor: 'rgba(52,199,89,0.10)' },
  card: {
    padding: spacing.lg,
    boxShadow: '0 8px 18px rgba(91, 120, 149, 0.10)',
  },
  header: { minHeight: 56, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 12, boxShadow: '0 8px 20px rgba(91, 120, 149, 0.08)' },
  backButton: { position: 'absolute', left: 9, width: 38, height: 38, alignItems: 'center', justifyContent: 'center', borderRadius: 19, backgroundColor: 'rgba(255,255,255,0.54)' },
  headerText: { alignItems: 'center', maxWidth: '72%' },
  headerTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 20, fontWeight: '800', letterSpacing: -0.4 },
  headerSubtitle: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: 1 },
  headerAction: { position: 'absolute', right: 9 },
  button: { minHeight: 48, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: 8, borderRadius: radii.md, backgroundColor: colors.blue, paddingHorizontal: spacing.lg },
  buttonSecondary: { backgroundColor: colors.blueSoft, borderWidth: 1, borderColor: '#D5E9FC' },
  buttonDanger: { backgroundColor: colors.red },
  buttonDisabled: { opacity: 0.55 },
  buttonPressed: { opacity: 0.82, transform: [{ scale: 0.99 }] },
  buttonText: { color: '#FFFFFF', fontFamily: fonts.body, fontWeight: '700', fontSize: 15 },
  buttonSecondaryText: { color: colors.blue },
  sectionTitleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.md },
  sectionTitleBlock: { flex: 1 },
  sectionTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800', letterSpacing: -0.3 },
  sectionDetail: { color: colors.muted, fontFamily: fonts.body, fontSize: 12, marginTop: 3 },
  tag: { alignSelf: 'flex-start', backgroundColor: colors.blueSoft, borderRadius: radii.pill, paddingHorizontal: 9, paddingVertical: 4 },
  tagGreen: { backgroundColor: colors.greenSoft },
  tagAmber: { backgroundColor: colors.amberSoft },
  tagRed: { backgroundColor: colors.redSoft },
  tagPlain: { backgroundColor: '#F1F5F9' },
  tagText: { color: colors.blue, fontFamily: fonts.body, fontWeight: '700', fontSize: 11 },
  tagGreenText: { color: '#16803D' },
  tagAmberText: { color: '#B76600' },
  tagRedText: { color: '#C93025' },
  tagPlainText: { color: colors.muted },
  metric: { gap: 6 },
  metricHead: { flexDirection: 'row', justifyContent: 'space-between', gap: spacing.md },
  metricLabel: { color: colors.ink, fontFamily: fonts.body, fontSize: 13, fontWeight: '600' },
  metricValue: { color: colors.muted, fontFamily: fonts.mono, fontSize: 12, fontWeight: '700' },
  progressTrack: { height: 6, borderRadius: radii.pill, backgroundColor: '#E8EFF6', overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: radii.pill },
  ringSvg: { position: 'absolute' },
  ringCenter: { alignItems: 'center', justifyContent: 'center' },
  ringNumber: { color: colors.ink, fontFamily: fonts.display, fontSize: 27, fontWeight: '800', letterSpacing: -1 },
  ringCaption: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, marginTop: -2 },
  logoIcon: { position: 'absolute', alignItems: 'center', justifyContent: 'center' },
  avatarWrap: { position: 'relative', overflow: 'visible' },
  avatarPressable: { width: '100%', height: '100%', borderRadius: radii.pill },
  avatar: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden', backgroundColor: colors.blue },
  avatarImage: { position: 'absolute', top: 0, left: 0, backgroundColor: colors.blueSoft },
  avatarText: { color: '#FFFFFF', fontFamily: fonts.display, fontWeight: '800' },
  avatarEditBadge: { position: 'absolute', right: -2, bottom: -2, width: 23, height: 23, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blue, borderWidth: 2, borderColor: '#FFFFFF' },
  empty: { alignItems: 'center', paddingVertical: spacing.xl },
  emptyIcon: { width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.blueSoft, marginBottom: spacing.md },
  emptyTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 17, fontWeight: '800' },
  emptyDescription: { color: colors.muted, fontFamily: fonts.body, fontSize: 13, textAlign: 'center', lineHeight: 20, marginTop: spacing.sm },
  emptyAction: { marginTop: spacing.lg, alignSelf: 'stretch' },
});
