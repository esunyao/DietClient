import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  Platform,
  Pressable,
  StatusBar,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ArrowLeft } from 'lucide-react-native';
import Animated, {
  interpolate,
  runOnJS,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import { durations, navigationTiming } from '../animation/config';
import { ScreenTransition } from '../animation/ScreenTransition';
import { colors, fonts, spacing } from '../theme/tokens';
import { GlassSurface } from './surfaces/GlassSurface';
import { PerfRegion } from '../perf/PerfRegion';
import { useScrollChrome } from '../scrollChrome/ScrollChromeProvider';
const HEADER_COLLAPSE_OFFSET = 36;
const HEADER_EXPAND_OFFSET = 12;
const HEADER_SAFE_GAP = 4;
const HEADER_HEIGHT = 44;
const COMPACT_HEADER_MIN_WIDTH = 86;
const COMPACT_HEADER_MAX_WIDTH = 158;
const COMPACT_HEADER_HEIGHT = 26;
/** 底部 tab 显隐过渡（UI 线程）。 */
const TabSlideTiming = navigationTiming(durations.tabBarSlide);
/** header 折叠过渡（UI 线程）。 */
const HeaderCollapseTiming = navigationTiming(durations.headerCollapse);

/** 每屏 header 状态：进度在 UI 线程，命中层只在跨阈值时同步到 JS。 */
type HeaderChrome = {
  progress: SharedValue<number>;
  collapsed: boolean;
};
const HeaderCollapsedContext = createContext<HeaderChrome | null>(null);
export function AppScreen({
  children,
  scroll = true,
  contentStyle,
  header,
}: {
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
  const [headerCollapsedForHitTesting, setHeaderCollapsedForHitTesting] = useState(false);

  // 新屏首帧：展开 header + 显示 tabbar（并清零本屏滚动基准）。
  useEffect(() => {
    chrome.tabHidden.value = 0;
    chrome.tabHiddenLogical.value = 0;
    headerCollapsed.value = 0;
    headerCollapsedLogical.value = 0;
    lastY.value = 0;
    setHeaderCollapsedForHitTesting(false);
    // 仅首帧执行；shared value 引用稳定，无需列入依赖。
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 与 htmlTest 的底部导航一致：向下滚动超过 80px 隐藏，向上滚动或回到顶部显示。
  // 全部在 UI 线程 worklet 中计算，滚动期间 JS 线程零参与。
  const scrollHandler = useAnimatedScrollHandler(
    {
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
              runOnJS(setHeaderCollapsedForHitTesting)(true);
            }
          } else if (y < HEADER_EXPAND_OFFSET) {
            if (headerCollapsedLogical.value === 1) {
              headerCollapsedLogical.value = 0;
              headerCollapsed.value = withTiming(0, HeaderCollapseTiming);
              runOnJS(setHeaderCollapsedForHitTesting)(false);
            }
          }
        }
        chrome.scrollY.value = y;
      },
    },
    [hasHeader],
  );
  const content = (
    <PerfRegion name="AppScreen">
      {scroll ? (
        <Animated.ScrollView
          contentContainerStyle={[
            styles.scrollContent,
            {
              paddingTop: contentTop,
            },
            contentStyle,
          ]}
          onScroll={scrollHandler}
          scrollEventThrottle={16}
          showsVerticalScrollIndicator={false}
        >
          {children}
        </Animated.ScrollView>
      ) : (
        <View
          style={[
            styles.fill,
            {
              paddingTop: contentTop,
            },
            contentStyle,
          ]}
        >
          {children}
        </View>
      )}
    </PerfRegion>
  );
  return (
    <ScreenTransition style={styles.screen}>
      {content}
      {header ? (
        <View
          style={[
            styles.floatingHeader,
            {
              top: safeTop + HEADER_SAFE_GAP,
            },
          ]}
        >
          <HeaderCollapsedContext.Provider
            value={{
              progress: headerCollapsed,
              collapsed: headerCollapsedForHitTesting,
            }}
          >
            {header}
          </HeaderCollapsedContext.Provider>
        </View>
      ) : null}
    </ScreenTransition>
  );
}

// 玻璃卡片组件

/**
 * 扁平“灵动岛”式悬浮胶囊：紧凑高度 + 大圆角 + 软阴影 + 细亮描边。
 * 通常作为 AppScreen 的 header 浮层使用，内容可从中滚过露出磨砂玻璃。
 */
export function ScreenHeader({
  title,
  subtitle,
  onBack,
  action,
}: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  action?: React.ReactNode;
}) {
  const collapse = useContext(HeaderCollapsedContext);
  // 折叠进度（0 展开 → 1 折叠），由 AppScreen 的 UI 线程滚动驱动。
  const c = useDerivedValue(() => collapse?.progress.value ?? 0);
  const isCollapsed = collapse?.collapsed ?? false;
  const compactWidth = Math.min(
    COMPACT_HEADER_MAX_WIDTH,
    Math.max(COMPACT_HEADER_MIN_WIDTH, title.length * 15 + 28),
  );
  const compactFontSize = title.length > 7 ? 10.5 : title.length > 5 ? 11.5 : 13;

  // 展开态标题：折叠时上移淡出。
  const expandedStyle = useAnimatedStyle(() => ({
    opacity: interpolate(c.value, [0, 0.5, 1], [1, 0, 0]),
    transform: [
      {
        translateY: -6 * c.value,
      },
    ],
  }));
  // 折叠态窄岛标题：展开时上移淡出。
  const compactStyle = useAnimatedStyle(() => ({
    opacity: interpolate(c.value, [0, 0.35, 1], [0, 0, 1]),
    transform: [
      {
        translateY: 6 * (1 - c.value),
      },
    ],
  }));
  const sideStyle = useAnimatedStyle(() => ({
    opacity: interpolate(c.value, [0, 0.35, 1], [0, 0, 1]),
  }));
  return (
    <PerfRegion name="ScreenHeader">
      <View style={styles.headerShell}>
        <Animated.View
          pointerEvents={isCollapsed ? 'none' : 'auto'}
          style={[styles.headerExpanded, expandedStyle]}
        >
          <GlassSurface
            capture={!isCollapsed}
            captureGroup="header"
            cornerRadius={HEADER_HEIGHT / 2}
            elevated
            intensity={38}
            variant="navigation"
            style={styles.header}
          >
            <View style={styles.headerText}>
              <Text style={styles.headerTitle}>{title}</Text>
              {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
            </View>
            {onBack ? (
              <Pressable
                accessibilityLabel="返回"
                hitSlop={10}
                onPress={onBack}
                style={styles.backButton}
              >
                <ArrowLeft color={colors.ink} size={17} />
              </Pressable>
            ) : null}
            {action ? <View style={styles.headerAction}>{action}</View> : null}
          </GlassSurface>
        </Animated.View>
        <Animated.View
          pointerEvents="none"
          style={[
            styles.headerCompact,
            {
              width: compactWidth,
            },
            compactStyle,
          ]}
        >
          <GlassSurface
            capture={isCollapsed}
            captureGroup="header"
            cornerRadius={COMPACT_HEADER_HEIGHT / 2}
            elevated
            intensity={38}
            variant="navigation"
            style={styles.compactIsland}
          >
            <Text
              adjustsFontSizeToFit
              minimumFontScale={0.82}
              numberOfLines={1}
              style={[
                styles.compactTitle,
                {
                  fontSize: compactFontSize,
                },
              ]}
            >
              {title}
            </Text>
          </GlassSurface>
        </Animated.View>
        {onBack ? (
          <Animated.View
            pointerEvents={isCollapsed ? 'auto' : 'none'}
            style={[styles.headerSideLeft, sideStyle]}
          >
            <GlassSurface
              cornerRadius={COMPACT_HEADER_HEIGHT / 2}
              elevated
              variant="soft"
              style={styles.headerSideButton}
            >
              <Pressable
                accessibilityLabel="返回"
                hitSlop={10}
                onPress={onBack}
                style={styles.sideButtonPressable}
              >
                <ArrowLeft color={colors.ink} size={17} />
              </Pressable>
            </GlassSurface>
          </Animated.View>
        ) : null}
        {action ? (
          <Animated.View
            pointerEvents={isCollapsed ? 'auto' : 'none'}
            style={[styles.headerSideRight, sideStyle]}
          >
            <GlassSurface
              cornerRadius={COMPACT_HEADER_HEIGHT / 2}
              elevated
              variant="soft"
              style={styles.headerSideButton}
            >
              {action}
            </GlassSurface>
          </Animated.View>
        ) : null}
      </View>
    </PerfRegion>
  );
}
const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.canvas,
    overflow: 'hidden',
  },
  fill: {
    flex: 1,
  },
  scrollContent: {
    zIndex: 1,
    paddingHorizontal: spacing.lg,
    paddingBottom: 104,
    gap: spacing.lg,
  },
  floatingHeader: {
    position: 'absolute',
    left: spacing.lg,
    right: spacing.lg,
    zIndex: 60,
  },
  headerShell: {
    height: HEADER_HEIGHT,
    justifyContent: 'center',
  },
  headerExpanded: {
    height: HEADER_HEIGHT,
    width: '100%',
  },
  headerCompact: {
    position: 'absolute',
    top: 0,
    alignSelf: 'center',
    height: COMPACT_HEADER_HEIGHT,
  },
  header: {
    height: HEADER_HEIGHT,
    borderRadius: HEADER_HEIGHT / 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  compactIsland: {
    height: COMPACT_HEADER_HEIGHT,
    borderRadius: COMPACT_HEADER_HEIGHT / 2,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.sm,
  },
  backButton: {
    position: 'absolute',
    left: 6,
    top: (HEADER_HEIGHT - 32) / 2,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 16,
    backgroundColor: 'rgba(255, 255, 255, 0.46)',
  },
  headerText: {
    alignItems: 'center',
    maxWidth: '70%',
  },
  headerTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 16,
    fontWeight: '800',
    letterSpacing: -0.3,
  },
  headerSubtitle: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 9,
    marginTop: 1,
  },
  headerAction: {
    position: 'absolute',
    right: 6,
    top: (HEADER_HEIGHT - COMPACT_HEADER_HEIGHT) / 2,
  },
  compactTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: -0.2,
  },
  headerSideLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
  },
  headerSideRight: {
    position: 'absolute',
    right: 0,
    top: 0,
  },
  headerSideButton: {
    width: COMPACT_HEADER_HEIGHT,
    height: COMPACT_HEADER_HEIGHT,
    borderRadius: COMPACT_HEADER_HEIGHT / 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sideButtonPressable: {
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: COMPACT_HEADER_HEIGHT / 2,
  },
});

// 动画实现（reanimated 驱动）集中在 shared/animation，对调用方保持原签名不变。
