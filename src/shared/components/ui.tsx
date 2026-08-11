import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Platform,
  Pressable,
  StatusBar,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ArrowLeft, Camera, Sparkles, Utensils } from 'lucide-react-native';
import Animated, {
  Easing,
  ReduceMotion,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';

import { durations } from '../animation/config';
import { PressableScale } from '../animation/PressableScale';
import { ScreenTransition } from '../animation/ScreenTransition';
import { colors, fonts, glow, radii, shadows, spacing } from '../theme/tokens';
import { GlassSurface } from './GlassSurface';
import { PerfRegion } from '../perf/PerfRegion';
import { useScrollChrome } from '../scrollChrome/ScrollChromeProvider';

const HEADER_COLLAPSE_OFFSET = 56;
const HEADER_EXPAND_OFFSET = 24;
const HEADER_SAFE_GAP = 4;
const HEADER_HEIGHT = 44;
const COMPACT_HEADER_WIDTH = 136;
const COMPACT_HEADER_HEIGHT = 34;

/** 底部 tab 显隐过渡（UI 线程）。 */
const TabSlideTiming = {
  duration: durations.tabBarSlide,
  easing: Easing.inOut(Easing.cubic),
  reduceMotion: ReduceMotion.System,
};
/** header 折叠过渡（UI 线程）。 */
const HeaderCollapseTiming = {
  duration: durations.headerCollapse,
  easing: Easing.inOut(Easing.cubic),
  reduceMotion: ReduceMotion.System,
};

/** 每屏 header 折叠进度（0 展开 / 1 折叠，含过渡中间值），由 AppScreen 的 UI 线程滚动驱动。 */
const HeaderCollapsedContext = createContext<SharedValue<number> | null>(null);

export function AppScreen({ children, scroll = true, contentStyle, header }: {
  children: React.ReactNode;
  scroll?: boolean;
  contentStyle?: StyleProp<ViewStyle>;
  /** 悬浮在内容之上的玻璃胶囊栏（灵动岛式）。传入时内容顶部自动让位。 */
  header?: React.ReactNode;
}) {
  const insets = useSafeAreaInsets();
  const chrome = useScrollChrome();
  const hasHeader = Boolean(header);
  const statusBarHeight = Platform.OS === 'android' ? StatusBar.currentHeight || 0 : 0;
  const safeTop = Math.max(insets.top, statusBarHeight);
  const contentTop = hasHeader
    ? safeTop + HEADER_SAFE_GAP + HEADER_HEIGHT + spacing.lg
    : safeTop + spacing.md;

  // 每屏自己的折叠态与滚动基准（shared value，全部在 UI 线程工作）。
  const headerCollapsed = useSharedValue(0);
  const headerCollapsedLogical = useSharedValue(0);
  const lastY = useSharedValue(0);

  // 新屏首帧：展开 header + 显示 tabbar（并清零本屏滚动基准）。
  useEffect(() => {
    chrome.tabHidden.value = 0;
    chrome.tabHiddenLogical.value = 0;
    headerCollapsed.value = 0;
    headerCollapsedLogical.value = 0;
    lastY.value = 0;
    // 仅首帧执行；shared value 引用稳定，无需列入依赖。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 与 htmlTest 的底部导航一致：向下滚动超过 80px 隐藏，向上滚动或回到顶部显示。
  // 全部在 UI 线程 worklet 中计算，滚动期间 JS 线程零参与。
  const scrollHandler = useAnimatedScrollHandler({
    onScroll: event => {
      'worklet';
      const y = Math.max(event.contentOffset.y, 0);
      const dy = y - lastY.value;
      lastY.value = y;

      // tabbar：仅在方向翻转且过阈值时改逻辑态，避免 220ms 过渡期被逐帧重赋值。
      if (dy > 0 && y > 80) {
        if (chrome.tabHiddenLogical.value === 0) {
          chrome.tabHiddenLogical.value = 1;
          chrome.tabHidden.value = withTiming(1, TabSlideTiming);
        }
      } else if (dy < 0 || y < 80) {
        if (chrome.tabHiddenLogical.value === 1) {
          chrome.tabHiddenLogical.value = 0;
          chrome.tabHidden.value = withTiming(0, TabSlideTiming);
        }
      }

      // header 折叠：跨阈值翻转（带迟滞区间）。
      if (hasHeader) {
        if (y > HEADER_COLLAPSE_OFFSET) {
          if (headerCollapsedLogical.value === 0) {
            headerCollapsedLogical.value = 1;
            headerCollapsed.value = withTiming(1, HeaderCollapseTiming);
          }
        } else if (y < HEADER_EXPAND_OFFSET) {
          if (headerCollapsedLogical.value === 1) {
            headerCollapsedLogical.value = 0;
            headerCollapsed.value = withTiming(0, HeaderCollapseTiming);
          }
        }
      }

      chrome.scrollY.value = y;
    },
  }, [hasHeader]);

  const content = (
    <PerfRegion name="AppScreen">
      {scroll ? (
        <Animated.ScrollView
          contentContainerStyle={[styles.scrollContent, { paddingTop: contentTop }, contentStyle]}
          onScroll={scrollHandler}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
        >
          {children}
        </Animated.ScrollView>
      ) : (
        <View style={[styles.fill, { paddingTop: contentTop }, contentStyle]}>
          {children}
        </View>
      )}
    </PerfRegion>
  );

  return (
    <ScreenTransition style={styles.screen}>
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
    </ScreenTransition>
  );
}

// 玻璃卡片组件
export function GlassCard({ children, style, variant = 'soft', elevated = false }: {
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
  const collapse = useContext(HeaderCollapsedContext);
  // 折叠进度（0 展开 → 1 折叠），由 AppScreen 的 UI 线程滚动驱动。
  const c = useDerivedValue(() => collapse?.value ?? 0);

  // 展开态标题：折叠时上移淡出。
  const expandedStyle = useAnimatedStyle(() => ({
    opacity: 1 - c.value,
    transform: [{ translateY: -6 * c.value }],
  }));
  // 折叠态窄岛标题：展开时上移淡出。
  const compactStyle = useAnimatedStyle(() => ({
    opacity: c.value,
    transform: [{ translateY: 6 * (1 - c.value) }],
  }));

  return (
    <PerfRegion name="ScreenHeader">
      <View style={styles.headerShell}>
        {/* 单 blur 容器：恒一条全宽模糊胶囊，expanded/compact 两层标题交叉淡入。
            相比之前 2 个 BlurView，挂载初始化成本减半（每个 BlurView 约 15-30ms）。 */}
        <GlassSurface variant="navigation" intensity={50} style={styles.header}>
          <Animated.View pointerEvents="box-none" style={[styles.headerFill, expandedStyle]}>
            <View style={styles.headerText}>
              <Text style={styles.headerTitle}>{title}</Text>
              {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
            </View>
          </Animated.View>
          <Animated.View pointerEvents="none" style={[styles.headerFill, compactStyle]}>
            <View style={styles.compactIsland}>
              <Text numberOfLines={1} style={styles.compactTitle}>{title}</Text>
            </View>
          </Animated.View>
          {onBack ? (
            <Pressable accessibilityLabel="返回" hitSlop={10} onPress={onBack} style={styles.backButton}>
              <ArrowLeft color={colors.ink} size={17} />
            </Pressable>
          ) : null}
          {action ? <View style={styles.headerAction}>{action}</View> : null}
        </GlassSurface>
      </View>
    </PerfRegion>
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
    <PressableScale
      accessibilityRole="button"
      disabled={isDisabled}
      onPress={onPress}
      style={[
        styles.button,
        variant === 'secondary' && styles.buttonSecondary,
        variant === 'danger' && styles.buttonDanger,
        isDisabled && styles.buttonDisabled,
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={variant === 'secondary' ? colors.blue : '#FFFFFF'} size="small" /> : null}
      <Text style={[styles.buttonText, variant === 'secondary' && styles.buttonSecondaryText]}>{label}</Text>
    </PressableScale>
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
  // 图片加载状态：loaded 后不再渲染 SVG 占位层（省 GPU 填充），失败时回退 SVG 首字母。
  const [imageState, setImageState] = useState<'pending' | 'loaded' | 'failed'>(() => (avatarUrl ? 'pending' : 'failed'));

  useEffect(() => {
    setImageState(avatarUrl ? 'pending' : 'failed');
  }, [avatarUrl]);

  // pending（加载中）与 failed 显示 SVG 占位；loaded 后只显示头像图。
  const showFallback = imageState !== 'loaded';
  const showImage = Boolean(avatarUrl) && imageState !== 'failed';

  const content = (
    <>
      <View style={[styles.avatar, { width: size, height: size, borderRadius: size / 2 }]}>
        {showFallback ? (
          <>
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
          </>
        ) : null}
      </View>
      {showImage ? (
        <Image
          accessibilityLabel={`${name}的头像`}
          onLoad={() => setImageState('loaded')}
          onError={() => {
            setImageState('failed');
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
  /** 单 blur 容器内的标题层：绝对填充、居中。 */
  headerFill: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },
  header: { height: HEADER_HEIGHT, borderRadius: HEADER_HEIGHT / 2, boxShadow: shadows.soft },
  compactIsland: { minWidth: COMPACT_HEADER_WIDTH, height: COMPACT_HEADER_HEIGHT, borderRadius: COMPACT_HEADER_HEIGHT / 2, alignItems: 'center', justifyContent: 'center', paddingHorizontal: spacing.md, backgroundColor: 'rgba(255,255,255,0.66)', boxShadow: shadows.soft },
  backButton: { position: 'absolute', left: 6, top: (HEADER_HEIGHT - 32) / 2, width: 32, height: 32, alignItems: 'center', justifyContent: 'center', borderRadius: 16, backgroundColor: 'rgba(255,255,255,0.6)' },
  headerText: { alignItems: 'center', maxWidth: '70%' },
  headerTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 16, fontWeight: '800', letterSpacing: -0.3 },
  headerSubtitle: { color: colors.muted, fontFamily: fonts.body, fontSize: 9, marginTop: 1 },
  headerAction: { position: 'absolute', right: 6, top: (HEADER_HEIGHT - COMPACT_HEADER_HEIGHT) / 2 },
  compactTitle: { color: colors.ink, fontFamily: fonts.display, fontSize: 14, fontWeight: '800', letterSpacing: -0.2 },
  button: { minHeight: 48, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: 8, borderRadius: radii.md, backgroundColor: colors.blue, paddingHorizontal: spacing.lg },
  buttonSecondary: { backgroundColor: colors.blueSoft, borderWidth: 1, borderColor: '#D5E9FC' },
  buttonDanger: { backgroundColor: colors.red },
  buttonDisabled: { opacity: 0.55 },
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
  statCell: { alignItems: 'center', gap: 3 },
  statCellLabel: { color: colors.muted, fontFamily: fonts.body, fontSize: 10, letterSpacing: 0.4 },
  statCellValue: { color: colors.ink, fontFamily: fonts.display, fontSize: 18, fontWeight: '800', letterSpacing: -0.5 },
  statCellUnit: { color: colors.muted, fontFamily: fonts.body, fontSize: 11, fontWeight: '600' },
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

// 动画实现（reanimated 驱动）集中在 shared/animation，对调用方保持原签名不变。
export { AnimatedProgress as MetricProgress } from '../animation/AnimatedProgress';
export { AnimatedScoreRing as ScoreRing } from '../animation/AnimatedScoreRing';
