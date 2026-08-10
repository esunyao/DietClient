import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  Image,
  Platform,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ArrowLeft, Camera, Sparkles, Utensils } from 'lucide-react-native';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';

import { colors, fonts, glow, radii, shadows, spacing } from '../theme/tokens';
import { GlassSurface } from './GlassSurface';
import { useTabBarVisibility } from '../store/tabBarVisibility';

const HEADER_COLLAPSE_OFFSET = 56;
const HEADER_EXPAND_OFFSET = 24;
const HEADER_SAFE_GAP = 4;
const HEADER_HEIGHT = 44;
const COMPACT_HEADER_WIDTH = 136;
const COMPACT_HEADER_HEIGHT = 34;

const HeaderCollapsedContext = createContext(false);

export function AppScreen({ children, scroll = true, contentStyle, header }: {
  children: React.ReactNode;
  scroll?: boolean;
  contentStyle?: StyleProp<ViewStyle>;
  /** 悬浮在内容之上的玻璃胶囊栏（灵动岛式）。传入时内容顶部自动让位。 */
  header?: React.ReactNode;
}) {
  const insets = useSafeAreaInsets();
  const setHidden = useTabBarVisibility(state => state.setHidden);
  const lastY = useRef(0);
  const hiddenRef = useRef(false);
  const headerCollapsedRef = useRef(false);
  const [headerCollapsed, setHeaderCollapsed] = useState(false);
  const hasHeader = Boolean(header);
  const statusBarHeight = Platform.OS === 'android' ? StatusBar.currentHeight || 0 : 0;
  const safeTop = Math.max(insets.top, statusBarHeight);
  const contentTop = hasHeader
    ? safeTop + HEADER_SAFE_GAP + HEADER_HEIGHT + spacing.lg
    : safeTop + spacing.md;

  const updateHeaderCollapsed = useCallback((next: boolean) => {
    if (next !== headerCollapsedRef.current) {
      headerCollapsedRef.current = next;
      setHeaderCollapsed(next);
    }
  }, []);

  // 与 htmlTest 的底部导航一致：向下滚动超过 80px 隐藏，向上滚动或回到顶部显示。
  // 仅在方向翻转时写 store，避免每帧触发重渲染。
  const handleScroll = useCallback((event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const y = Math.max(event.nativeEvent.contentOffset.y, 0);
    const dy = y - lastY.current;
    let next = hiddenRef.current;
    if (dy > 0 && y > 80) {
      next = true;
    } else if (dy < 0 || y < 80) {
      next = false;
    }
    lastY.current = y;
    if (next !== hiddenRef.current) {
      hiddenRef.current = next;
      setHidden(next);
    }
    if (hasHeader) {
      if (y > HEADER_COLLAPSE_OFFSET) {
        updateHeaderCollapsed(true);
      } else if (y < HEADER_EXPAND_OFFSET) {
        updateHeaderCollapsed(false);
      }
    }
  }, [hasHeader, setHidden, updateHeaderCollapsed]);

  useEffect(() => {
    if (!hasHeader) {
      updateHeaderCollapsed(false);
    }
  }, [hasHeader, updateHeaderCollapsed]);

  const content = scroll ? (
    <ScrollView
      contentContainerStyle={[styles.scrollContent, { paddingTop: contentTop }, contentStyle]}
      onScroll={handleScroll}
      scrollEventThrottle={16}
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.fill, { paddingTop: contentTop }, contentStyle]}>{children}</View>
  );

  return (
    <View style={styles.screen}>
      <View pointerEvents="none" style={styles.canvasGlowOne} />
      <View pointerEvents="none" style={styles.canvasGlowTwo} />
      {content}
      {header ? (
        <View style={[styles.floatingHeader, { top: safeTop + HEADER_SAFE_GAP }]}>
          <HeaderCollapsedContext.Provider value={headerCollapsed}>
            {header}
          </HeaderCollapsedContext.Provider>
        </View>
      ) : null}
    </View>
  );
}

// 玻璃卡片组件
export function GlassCard({ children, style, variant = 'frosted', elevated = true }: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  variant?: 'frosted' | 'soft';
  elevated?: boolean;
}) {
  return <GlassSurface variant={variant} style={[styles.card, elevated && styles.cardElevated, style]}>{children}</GlassSurface>;
}

/**
 * 扁平“灵动岛”式悬浮胶囊：紧凑高度 + 大圆角 + 软阴影 + 细亮描边。
 * 通常作为 AppScreen 的 header 浮层使用，内容可从中滚过露出磨砂玻璃。
 */
export function ScreenHeader({ title, subtitle, onBack, action }: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  action?: React.ReactNode;
}) {
  const collapsed = useContext(HeaderCollapsedContext);
  const progress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(progress, {
      toValue: collapsed ? 1 : 0,
      duration: 180,
      useNativeDriver: true,
    }).start();
  }, [collapsed, progress]);

  const expandedOpacity = progress.interpolate({ inputRange: [0, 1], outputRange: [1, 0] });
  const compactOpacity = progress;
  const compactScale = progress.interpolate({ inputRange: [0, 1], outputRange: [0.9, 1] });

  return (
    <View style={styles.headerShell}>
      <Animated.View pointerEvents={collapsed ? 'none' : 'auto'} style={[styles.headerExpanded, { opacity: expandedOpacity }]}>
        <GlassSurface variant="navigation" intensity={68} style={styles.header}>
          {onBack ? (
            <Pressable accessibilityLabel="返回" hitSlop={10} onPress={onBack} style={styles.backButton}>
              <ArrowLeft color={colors.ink} size={17} />
            </Pressable>
          ) : null}
          <View style={styles.headerText}>
            <Text style={styles.headerTitle}>{title}</Text>
            {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
          </View>
          {action ? <View style={styles.headerAction}>{action}</View> : null}
        </GlassSurface>
      </Animated.View>
      <Animated.View pointerEvents="none" style={[styles.headerCompact, { opacity: compactOpacity, transform: [{ scale: compactScale }] }]}>
        <GlassSurface variant="navigation" intensity={72} style={styles.compactIsland}>
          <Text numberOfLines={1} style={styles.compactTitle}>{title}</Text>
        </GlassSurface>
      </Animated.View>
      {onBack ? (
        <Animated.View pointerEvents={collapsed ? 'auto' : 'none'} style={[styles.headerSideLeft, { opacity: compactOpacity }]}>
          <GlassSurface variant="navigation" intensity={72} style={styles.headerSideButton}>
            <Pressable accessibilityLabel="返回" hitSlop={10} onPress={onBack} style={styles.sideButtonPressable}>
              <ArrowLeft color={colors.ink} size={17} />
            </Pressable>
          </GlassSurface>
        </Animated.View>
      ) : null}
      {action ? (
        <Animated.View pointerEvents={collapsed ? 'auto' : 'none'} style={[styles.headerSideRight, { opacity: compactOpacity }]}>
          <GlassSurface variant="navigation" intensity={72} style={styles.headerSideButton}>
            {action}
          </GlassSurface>
        </Animated.View>
      ) : null}
    </View>
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

export function Tag({ label, tone = 'blue', style }: { label: string; tone?: 'blue' | 'green' | 'amber' | 'red' | 'plain'; style?: StyleProp<ViewStyle> }) {
  return (
    <View style={[styles.tag, tone === 'green' && styles.tagGreen, tone === 'amber' && styles.tagAmber, tone === 'red' && styles.tagRed, tone === 'plain' && styles.tagPlain, style]}>
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

/** 三列统计小格（热量/蛋白质/钠上限等），对齐 htmlTest 的个性化营养目标统计。 */
export function StatCell({ label, value, unit, style }: {
  label: string;
  value: string;
  unit?: string;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <View style={[styles.statCell, style]}>
      <Text style={styles.statCellLabel}>{label}</Text>
      <Text style={styles.statCellValue}>
        {value}
        {unit ? <Text style={styles.statCellUnit}> {unit}</Text> : null}
      </Text>
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
  scrollContent: { zIndex: 1, paddingHorizontal: spacing.lg, paddingBottom: 104, gap: spacing.lg },
  floatingHeader: { position: 'absolute', left: spacing.lg, right: spacing.lg, zIndex: 60 },
  canvasGlowOne: { position: 'absolute', width: 250, height: 250, borderRadius: 125, top: -120, right: -90, backgroundColor: glow.orbBlue },
  canvasGlowTwo: { position: 'absolute', width: 210, height: 210, borderRadius: 105, bottom: 100, left: -110, backgroundColor: glow.orbGreen },
  card: {
    padding: spacing.lg,
  },
  cardElevated: {
    boxShadow: shadows.card,
  },
  headerShell: { height: HEADER_HEIGHT, justifyContent: 'center' },
  headerExpanded: { height: HEADER_HEIGHT, width: '100%' },
  headerCompact: { position: 'absolute', top: 0, alignSelf: 'center', width: COMPACT_HEADER_WIDTH, height: COMPACT_HEADER_HEIGHT },
  header: { height: HEADER_HEIGHT, borderRadius: HEADER_HEIGHT / 2, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 6, boxShadow: shadows.soft },
  compactIsland: { height: COMPACT_HEADER_HEIGHT, borderRadius: COMPACT_HEADER_HEIGHT / 2, alignItems: 'center', justifyContent: 'center', paddingHorizontal: spacing.md, boxShadow: shadows.soft },
  backButton: { position: 'absolute', left: 6, width: 32, height: 32, alignItems: 'center', justifyContent: 'center', borderRadius: 16, backgroundColor: 'rgba(255,255,255,0.6)' },
  headerText: { alignItems: 'center', maxWidth: '70%' },
  headerTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 16, fontWeight: '800', letterSpacing: -0.3 },
  headerSubtitle: { color: colors.muted, fontFamily: fonts.body, fontSize: 9, marginTop: 1 },
  headerAction: { position: 'absolute', right: 6 },
  compactTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 14, fontWeight: '800', letterSpacing: -0.2 },
  headerSideLeft: { position: 'absolute', left: 0, top: 0 },
  headerSideRight: { position: 'absolute', right: 0, top: 0 },
  headerSideButton: { width: COMPACT_HEADER_HEIGHT, height: COMPACT_HEADER_HEIGHT, borderRadius: COMPACT_HEADER_HEIGHT / 2, alignItems: 'center', justifyContent: 'center', boxShadow: shadows.soft },
  sideButtonPressable: { width: '100%', height: '100%', alignItems: 'center', justifyContent: 'center', borderRadius: COMPACT_HEADER_HEIGHT / 2 },
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
  statCell: { alignItems: 'center', gap: 3 },
  statCellLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, letterSpacing: 0.4 },
  statCellValue: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800', letterSpacing: -0.5 },
  statCellUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, fontWeight: '600' },
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
