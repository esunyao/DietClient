import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { Camera, Sparkles, Utensils } from 'lucide-react-native';
import Svg, { Circle, Defs, LinearGradient, Stop } from 'react-native-svg';
import { PressableScale } from '../animation/PressableScale';
import { colors, fonts, radii, shadows, spacing } from '../theme/tokens';
import { GlassSurface } from './surfaces/GlassSurface';
// 玻璃卡片组件
export function GlassCard({
  children,
  style,
  variant = 'soft',
  elevated = false,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  variant?: 'frosted' | 'soft';
  elevated?: boolean;
}) {
  return (
    <GlassSurface
      elevated={elevated}
      variant={variant}
      style={[styles.card, elevated && styles.cardElevated, style]}
    >
      {children}
    </GlassSurface>
  );
}

/**
 * 扁平“灵动岛”式悬浮胶囊：紧凑高度 + 大圆角 + 软阴影 + 细亮描边。
 * 通常作为 AppScreen 的 header 浮层使用，内容可从中滚过露出磨砂玻璃。
 */

export function AppButton({
  label,
  onPress,
  loading,
  disabled,
  variant = 'primary',
  style,
  icon,
}: {
  label: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  variant?: 'primary' | 'secondary' | 'danger';
  style?: StyleProp<ViewStyle>;
  icon?: React.ReactNode;
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
      {loading ? (
        <ActivityIndicator color={variant === 'secondary' ? colors.blue : '#FFFFFF'} size="small" />
      ) : null}
      {!loading ? icon : null}
      <Text style={[styles.buttonText, variant === 'secondary' && styles.buttonSecondaryText]}>
        {label}
      </Text>
    </PressableScale>
  );
}
export function SectionTitle({
  title,
  detail,
  action,
}: {
  title: string;
  detail?: string;
  action?: React.ReactNode;
}) {
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
export function Tag({
  label,
  tone = 'blue',
  style,
}: {
  label: string;
  tone?: 'blue' | 'green' | 'amber' | 'red' | 'plain';
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <View
      style={[
        styles.tag,
        tone === 'green' && styles.tagGreen,
        tone === 'amber' && styles.tagAmber,
        tone === 'red' && styles.tagRed,
        tone === 'plain' && styles.tagPlain,
        style,
      ]}
    >
      <Text
        style={[
          styles.tagText,
          tone === 'green' && styles.tagGreenText,
          tone === 'amber' && styles.tagAmberText,
          tone === 'red' && styles.tagRedText,
          tone === 'plain' && styles.tagPlainText,
        ]}
      >
        {label}
      </Text>
    </View>
  );
}

/** 三列统计小格（热量/蛋白质/钠上限等），对齐 htmlTest 的个性化营养目标统计。 */
export function StatCell({
  label,
  value,
  unit,
  style,
}: {
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
  const containerStyle = {
    width: size,
    height: size,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  };
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
      <View style={styles.logoIcon}>
        <Utensils size={size * 0.38} color="#FFFFFF" strokeWidth={2.4} />
      </View>
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
  const [imageState, setImageState] = useState<'pending' | 'loaded' | 'failed'>(() =>
    avatarUrl ? 'pending' : 'failed',
  );
  useEffect(() => {
    setImageState(avatarUrl ? 'pending' : 'failed');
  }, [avatarUrl]);

  // pending（加载中）与 failed 显示 SVG 占位；loaded 后只显示头像图。
  const showFallback = imageState !== 'loaded';
  const showImage = Boolean(avatarUrl) && imageState !== 'failed';
  const content = (
    <>
      <View
        style={[
          styles.avatar,
          {
            width: size,
            height: size,
            borderRadius: size / 2,
          },
        ]}
      >
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
            <Text
              style={[
                styles.avatarText,
                {
                  fontSize: size * 0.36,
                },
              ]}
            >
              {initial}
            </Text>
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
          source={{
            uri: avatarUrl || undefined,
          }}
          style={[
            styles.avatarImage,
            {
              width: size,
              height: size,
              borderRadius: size / 2,
            },
          ]}
        />
      ) : null}
      {showEditBadge ? (
        <View style={styles.avatarEditBadge}>
          <Camera color="#FFFFFF" size={Math.max(12, size * 0.19)} />
        </View>
      ) : null}
    </>
  );
  return (
    <View
      style={[
        styles.avatarWrap,
        {
          width: size,
          height: size,
        },
      ]}
    >
      {onPress ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="更换头像"
          onPress={onPress}
          style={styles.avatarPressable}
        >
          {content}
        </Pressable>
      ) : (
        content
      )}
    </View>
  );
}
export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <GlassCard style={styles.empty}>
      <View style={styles.emptyIcon}>
        <Sparkles color={colors.blue} size={22} />
      </View>
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
  backgroundColor: colors.surface,
  color: colors.ink,
  fontFamily: fonts.body,
  fontSize: 15,
  paddingHorizontal: spacing.md,
};
const styles = StyleSheet.create({
  card: {
    padding: spacing.lg,
  },
  cardElevated: {
    boxShadow: shadows.card,
  },
  button: {
    minHeight: 48,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 8,
    borderRadius: radii.md,
    backgroundColor: colors.blue,
    paddingHorizontal: spacing.lg,
  },
  buttonSecondary: {
    backgroundColor: colors.blueSoft,
    borderWidth: 1,
    borderColor: colors.line,
  },
  buttonDanger: {
    backgroundColor: colors.red,
  },
  buttonDisabled: {
    opacity: 0.55,
  },
  buttonText: {
    color: '#FFFFFF',
    fontFamily: fonts.body,
    fontWeight: '700',
    fontSize: 15,
  },
  buttonSecondaryText: {
    color: colors.blue,
  },
  sectionTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.md,
  },
  sectionTitleBlock: {
    flex: 1,
  },
  sectionTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: -0.3,
  },
  sectionDetail: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 12,
    marginTop: 3,
  },
  tag: {
    alignSelf: 'flex-start',
    backgroundColor: colors.blueSoft,
    borderRadius: radii.pill,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  tagGreen: {
    backgroundColor: colors.greenSoft,
  },
  tagAmber: {
    backgroundColor: colors.amberSoft,
  },
  tagRed: {
    backgroundColor: colors.redSoft,
  },
  tagPlain: {
    backgroundColor: colors.surfaceMuted,
  },
  tagText: {
    color: colors.blue,
    fontFamily: fonts.body,
    fontWeight: '700',
    fontSize: 11,
  },
  tagGreenText: {
    color: '#16803D',
  },
  tagAmberText: {
    color: '#B76600',
  },
  tagRedText: {
    color: '#C93025',
  },
  tagPlainText: {
    color: colors.muted,
  },
  statCell: {
    alignItems: 'center',
    gap: 3,
  },
  statCellLabel: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 10,
    letterSpacing: 0.4,
  },
  statCellValue: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  statCellUnit: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 11,
    fontWeight: '600',
  },
  logoIcon: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarWrap: {
    position: 'relative',
    overflow: 'visible',
  },
  avatarPressable: {
    width: '100%',
    height: '100%',
    borderRadius: radii.pill,
  },
  avatar: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    backgroundColor: colors.blue,
  },
  avatarImage: {
    position: 'absolute',
    top: 0,
    left: 0,
    backgroundColor: colors.blueSoft,
  },
  avatarText: {
    color: '#FFFFFF',
    fontFamily: fonts.display,
    fontWeight: '800',
  },
  avatarEditBadge: {
    position: 'absolute',
    right: -2,
    bottom: -2,
    width: 23,
    height: 23,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blue,
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
  empty: {
    alignItems: 'center',
    paddingVertical: spacing.xl,
  },
  emptyIcon: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.blueSoft,
    marginBottom: spacing.md,
  },
  emptyTitle: {
    color: colors.ink,
    fontFamily: fonts.display,
    fontSize: 17,
    fontWeight: '800',
  },
  emptyDescription: {
    color: colors.muted,
    fontFamily: fonts.body,
    fontSize: 13,
    textAlign: 'center',
    lineHeight: 20,
    marginTop: spacing.sm,
  },
  emptyAction: {
    marginTop: spacing.lg,
    alignSelf: 'stretch',
  },
});

// 动画实现（reanimated 驱动）集中在 shared/animation，对调用方保持原签名不变。
// 动画实现（reanimated 驱动）集中在 shared/animation，对调用方保持原签名不变。
export { AnimatedProgress as MetricProgress } from '../animation/AnimatedProgress';
export { AnimatedScoreRing as ScoreRing } from '../animation/AnimatedScoreRing';
