import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  Platform,
  PixelRatio,
  StyleSheet,
  View,
  type GestureResponderEvent,
  type LayoutChangeEvent,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import {
  Blur,
  Canvas,
  Circle,
  Fill,
  Group,
  Image as SkiaImage,
  ImageShader,
  LinearGradient,
  Rect,
  RoundedRect,
  Shader,
  Skia,
  vec,
} from '@shopify/react-native-skia';
import Animated, {
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

import { radii } from '../../theme/tokens';
import {
  SkiaGlassSurface as SkiaGlassSurfaceNative,
  type SnapshotPayload,
} from '../../native/SkiaGlassSurface';
import {
  GLASS_LOOKS,
  LIQUID_BASE_FILL,
  LIQUID_OVERLAY_FILL,
  OPAQUE_FALLBACK_FILL,
  blurRadiusForIntensity,
  type GlassVariant,
} from './SkiaGlassSurfaceLook';
import {
  LIQUID_GLASS_SKSL,
  buildLiquidUniforms,
  type LiquidUniforms,
} from './SkiaGlassSurfaceShader';
import { normalizeSnapshotFrame } from './SkiaGlassSnapshotFrame';
import { durations, timing } from '../../animation/config';

/** canvas 单位换算：Android 为物理 px，iOS 为 points（RN Skia 双端坐标单位不同）。 */
const unitsPerDp = Platform.OS === 'android' ? PixelRatio.get() : 1;

/** 触摸光晕淡出与弹性回弹过渡。 */
const TouchTiming = timing(durations.touchOut);

/** 顶部高光高度（dp），对齐旧实现 2-3px 的细内高光。 */
const SHEEN_HEIGHT_DP = 2;

export type LiquidGlassOptions = {
  enabled?: boolean;
  touchEffect?: boolean;
  elasticEffect?: boolean;
  captureGroup?: 'header' | 'tab';
  refractionHeight?: number;
  refractionOffset?: number;
  blurRadius?: number;
  dispersion?: number;
};

export type SkiaGlassSurfaceProps = {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  intensity?: number;
  variant?: GlassVariant;
  /** 临时隐藏的导航层不再捕获背景，避免不可见材质持续占用快照预算。 */
  capture?: boolean;
  /** 导航快照分组；头部与底栏分开捕获，避免合并成长页面快照。 */
  captureGroup?: 'header' | 'tab';
  /** 兼容旧签名保留；Skia 模糊质量为 GPU 固定档位，此值仅作 API 兼容。 */
  blurRounds?: number;
  elevated?: boolean;
  cornerRadius?: number;
  liquid?: LiquidGlassOptions;
};

/**
 * 玻璃材质的 Skia 实现（原生端）。
 *
 * 背景模糊原理：Skia Canvas 是不透明表面，无法直接模糊其背后的 RN 视图，
 * 因此由原生 SkiaGlassSurface 容器持续捕获自身后方区域（0.5x、节流、去重），
 * 以 base64 JPEG 事件送 JS 解码为 SkImage，在 Canvas 内用 GPU ImageFilter 模糊。
 *
 * - soft：纯静态层（无 Canvas、无捕获），与旧实现观感一致、零成本。
 * - frosted / navigation：白底 + 模糊快照 + 覆盖 + 描边 + 顶部高光。
 * - navigation + liquid：SkSL 液态折射（移植自 AGSL shader）+ 触摸光晕 + 弹性缩放。
 */
export function SkiaGlassSurface({
  children,
  style,
  intensity = 50,
  variant = 'frosted',
  capture,
  captureGroup,
  blurRounds: _blurRounds = 2,
  elevated = false,
  cornerRadius = radii.lg,
  liquid,
}: SkiaGlassSurfaceProps) {
  const look = GLASS_LOOKS[variant];
  const useLiquid = Boolean(liquid?.enabled) && variant === 'navigation';
  const captureEnabled = capture ?? look.needsCapture;
  const isIOSSkiaFallback = Platform.OS === 'ios' && variant !== 'soft';

  // ---------- 尺寸与快照 ----------
  const [canvasSize, setCanvasSize] = useState({ width: 0, height: 0 });
  const [snapshot, setSnapshot] = useState<SnapshotPayload | null>(null);
  const [reduceTransparency, setReduceTransparency] = useState(false);
  const snapshotVersion = useRef(-1);
  const sizeRef = useRef({ width: 0, height: 0 });

  const handleLayout = useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    sizeRef.current = { width, height };
    setCanvasSize({ width, height });
  }, []);

  // iOS Reduce Transparency：对齐旧 BlurView 的 reducedTransparencyFallbackColor 纯色兜底。
  useEffect(() => {
    if (Platform.OS !== 'ios' || isIOSSkiaFallback) return;
    AccessibilityInfo.isReduceTransparencyEnabled()
      .then(setReduceTransparency)
      .catch(() => {});
    const subscription = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setReduceTransparency);
    return () => subscription.remove();
  }, [isIOSSkiaFallback]);

  const handleSnapshot = useCallback((payload: SnapshotPayload) => {
    if (!payload.jpeg || payload.width <= 0 || payload.height <= 0 || payload.contentScale <= 0) {
      snapshotVersion.current = -1;
      setSnapshot(null);
      return;
    }
    if (payload.version === snapshotVersion.current) return;
    snapshotVersion.current = payload.version;
    setSnapshot(payload);
  }, []);

  // 捕获关闭时丢弃旧快照，避免 header 折叠或离屏后继续显示上一帧背景。
  useEffect(() => {
    if (!captureEnabled) {
      snapshotVersion.current = -1;
      setSnapshot(null);
    }
  }, [captureEnabled]);

  // base64 → SkImage（解码在原生 JSI 内完成，小图亚毫秒级）。
  const snapshotImage = useMemo(() => {
    if (!snapshot) return null;
    try {
      return Skia.Image.MakeImageFromEncoded(Skia.Data.fromBase64(snapshot.jpeg));
    } catch {
      return null;
    }
  }, [snapshot]);

  // ---------- 液态触摸光晕与弹性（UI 线程共享值，Canvas 直接订阅，不触发 JS 重渲染） ----------
  const touchX = useSharedValue(0);
  const touchY = useSharedValue(0);
  const touchActive = useSharedValue(0);
  const glowOpacity = useDerivedValue(() => touchActive.value * 0.5);
  const downX = useSharedValue(0);
  const downY = useSharedValue(0);
  const scaleX = useSharedValue(1);
  const scaleY = useSharedValue(1);

  const handleTouchStart = useCallback((event: GestureResponderEvent) => {
    const { locationX, locationY } = event.nativeEvent;
    touchX.value = locationX * unitsPerDp;
    touchY.value = locationY * unitsPerDp;
    downX.value = locationX;
    downY.value = locationY;
    touchActive.value = 1;
  }, [downX, downY, touchActive, touchX, touchY]);

  const handleTouchMove = useCallback(
    (event: GestureResponderEvent) => {
      const { locationX, locationY } = event.nativeEvent;
      touchX.value = locationX * unitsPerDp;
      touchY.value = locationY * unitsPerDp;
      if (liquid?.elasticEffect) {
        const { width, height } = sizeRef.current;
        const dx = (locationX - downX.value) / Math.max(width, 1);
        const dy = (locationY - downY.value) / Math.max(height, 1);
        scaleX.value = Math.min(1.05, Math.max(0.96, 1 + Math.abs(dx) * 0.08 - Math.abs(dy) * 0.035));
        scaleY.value = Math.min(1.05, Math.max(0.96, 1 + Math.abs(dy) * 0.08 - Math.abs(dx) * 0.035));
      }
    },
    [downX, downY, liquid?.elasticEffect, scaleX, scaleY, touchX, touchY],
  );

  const handleTouchEnd = useCallback(() => {
    touchActive.value = withTiming(0, TouchTiming);
    scaleX.value = withTiming(1, TouchTiming);
    scaleY.value = withTiming(1, TouchTiming);
  }, [scaleX, scaleY, touchActive]);

  const elasticStyle = useAnimatedStyle(() => ({
    transform: [{ scaleX: scaleX.value }, { scaleY: scaleY.value }],
  }));

  // ---------- 绘制参数 ----------
  // onLayout 尺寸为 dp；canvas 坐标按平台换算（Android px / iOS points）。
  const canvasW = canvasSize.width * unitsPerDp;
  const canvasH = canvasSize.height * unitsPerDp;
  const radius = cornerRadius * unitsPerDp;
  const sheenHeight = SHEEN_HEIGHT_DP * unitsPerDp;
  const glowRadius = Math.max(canvasW, canvasH) * 0.55;
  const snapshotFrame = useMemo(
    () => snapshot
      ? normalizeSnapshotFrame({
          width: snapshot.width,
          height: snapshot.height,
          sourceOffsetX: snapshot.sourceOffsetX,
          sourceOffsetY: snapshot.sourceOffsetY,
          contentScale: snapshot.contentScale,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
        })
      : null,
    [canvasH, canvasW, snapshot],
  );

  // 圆角裁剪矩形：Skia clip 只接受 SkRRect，用 RRectXY 构造。
  const clipRRect = useMemo(() => {
    if (canvasW <= 0 || canvasH <= 0) return null;
    return Skia.RRectXY(Skia.XYWHRect(0, 0, canvasW, canvasH), radius, radius);
  }, [canvasW, canvasH, radius]);

  const liquidEffect = useMemo(() => {
    try {
      return Skia.RuntimeEffect.Make(LIQUID_GLASS_SKSL);
    } catch {
      return null;
    }
  }, []);

  const liquidUniforms: LiquidUniforms | null = useMemo(() => {
    if (!useLiquid || !snapshot || canvasW <= 0 || canvasH <= 0) return null;
    return buildLiquidUniforms({
      width: canvasW,
      height: canvasH,
      cornerRadius: radius,
      refractionHeight: (liquid?.refractionHeight ?? 20) * unitsPerDp,
      refractionOffset: (liquid?.refractionOffset ?? 70) * unitsPerDp,
      dispersion: liquid?.dispersion ?? 0.5,
      blurRadius: liquid?.blurRadius ?? 10,
      sourceOffsetX: snapshot.sourceOffsetX,
      sourceOffsetY: snapshot.sourceOffsetY,
      contentScale: snapshot.contentScale,
    });
  }, [useLiquid, snapshot, canvasW, canvasH, radius, liquid?.refractionHeight, liquid?.refractionOffset, liquid?.dispersion, liquid?.blurRadius]);

  const showSnapshot = Boolean(snapshotImage && snapshotFrame) && !reduceTransparency;
  const baseFill = reduceTransparency
    ? OPAQUE_FALLBACK_FILL
    : useLiquid
      ? LIQUID_BASE_FILL
      : look.baseFill;
  const overlayFill = reduceTransparency ? null : useLiquid ? LIQUID_OVERLAY_FILL : look.overlay;
  const blur = blurRadiusForIntensity(intensity);

  // iOS 的生产入口使用 UIVisualEffectView；直接调用 Skia 组件时也必须拒绝快照，
  // 避免未来绕过 GlassSurface 再次把宿主自身拍进背景。
  if (isIOSSkiaFallback) {
    return (
      <View
        pointerEvents="box-none"
        style={[styles.surface, styles.iosFallbackSurface, { borderRadius: cornerRadius }, style]}
      >
        <View pointerEvents="none" style={styles.sheen} />
        {children}
      </View>
    );
  }

  // ---------- 渲染 ----------
  // soft：纯静态层，不挂 Canvas 与捕获，与旧实现完全一致。
  if (variant === 'soft') {
    return (
      <View pointerEvents="box-none" style={[styles.surface, styles.softSurface, style]}>
        <View pointerEvents="none" style={styles.sheen} />
        {children}
      </View>
    );
  }

  const touchHandlers =
    useLiquid && liquid?.touchEffect
      ? {
          onTouchStart: handleTouchStart,
          onTouchMove: handleTouchMove,
          onTouchEnd: handleTouchEnd,
          onTouchCancel: handleTouchEnd,
        }
      : null;

  const container = (
    <SkiaGlassSurfaceNative
      cornerRadius={cornerRadius}
      elevated={elevated}
      live={captureEnabled}
      liquidEnabled={useLiquid}
      liquidCaptureGroup={captureGroup ?? liquid?.captureGroup ?? 'tab'}
      liquidRefractionHeight={liquid?.refractionHeight ?? 20}
      liquidRefractionOffset={liquid?.refractionOffset ?? 70}
      liquidBlurRadius={liquid?.blurRadius ?? 10}
      liquidDispersion={liquid?.dispersion ?? 0.5}
      onLayout={handleLayout}
      onSnapshot={handleSnapshot}
      style={[styles.surface, style]}
      {...touchHandlers}
    >
      <Canvas style={styles.canvas} pointerEvents="none">
        <Group clip={clipRRect ?? undefined}>
          {/* 白底：圆角外露出的角落与无快照时的基底（对齐旧背景色）。 */}
          <Fill color={baseFill} />
          {snapshot && showSnapshot ? (
            useLiquid && liquidEffect && liquidUniforms ? (
              <Rect x={0} y={0} width={canvasW} height={canvasH}>
                <Shader source={liquidEffect} uniforms={liquidUniforms}>
                  {/* 不传 x/y/width/height：ImageShader 保持图像像素 1:1 局部空间，
                      与 SkSL 内 (coord + sourceOffset) * contentScale 换算一致。 */}
                  <ImageShader image={snapshotImage} tx="clamp" ty="clamp" />
                </Shader>
              </Rect>
            ) : (
              // 快照按内容空间 1:1 绘制（目标矩形 = 快照像素 / contentScale 并偏移回玻璃原点），
              // 避免 fit 拉伸造成的背景缩放；超出画布部分由圆角裁剪裁掉。
              <SkiaImage
                image={snapshotImage}
                x={snapshotFrame?.x ?? 0}
                y={snapshotFrame?.y ?? 0}
                width={snapshotFrame?.width ?? 0}
                height={snapshotFrame?.height ?? 0}
                fit="fill"
              >
                <Blur blur={blur} />
              </SkiaImage>
            )
          ) : null}
          {overlayFill ? <Fill color={overlayFill} /> : null}
          {/* 1px 细描边（内收 0.5，对齐旧实现）。 */}
          <RoundedRect
            x={0.5}
            y={0.5}
            width={Math.max(0, canvasW - 1)}
            height={Math.max(0, canvasH - 1)}
            r={Math.max(0, radius - 0.5)}
            style="stroke"
            strokeWidth={1}
            color={look.border}
          />
          {/* 顶部细内高光：仿 iOS 材质的高光描边。 */}
          <Rect x={0} y={0} width={canvasW} height={sheenHeight}>
            <LinearGradient
              start={vec(0, 0)}
              end={vec(0, sheenHeight)}
              colors={[look.sheen, 'rgba(255, 255, 255, 0)']}
            />
          </Rect>
          {/* 液态触摸光晕。 */}
          {useLiquid && liquid?.touchEffect ? (
            <Circle cx={touchX} cy={touchY} r={glowRadius} color="rgba(255, 255, 255, 0.55)" opacity={glowOpacity} />
          ) : null}
        </Group>
      </Canvas>
      {children}
    </SkiaGlassSurfaceNative>
  );

  if (useLiquid && liquid?.elasticEffect) {
    // 包裹层随容器自适应尺寸，scale 变换仅作用于视觉。
    return <Animated.View style={elasticStyle}>{container}</Animated.View>;
  }
  return container;
}

const styles = StyleSheet.create({
  surface: {
    overflow: 'hidden',
    borderWidth: 0,
    backgroundColor: 'transparent',
  },
  canvas: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  softSurface: {
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.78)',
    borderRadius: radii.lg,
    backgroundColor: 'rgba(255, 255, 255, 0.54)',
  },
  iosFallbackSurface: {
    borderWidth: 1,
    borderColor: GLASS_LOOKS.navigation.border,
    backgroundColor: OPAQUE_FALLBACK_FILL,
  },
  /** 顶部细内高光：仿 iOS 材质的高光描边，让玻璃轮廓更分明。 */
  sheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: StyleSheet.hairlineWidth * 3,
    backgroundColor: 'rgba(255, 255, 255, 0.34)',
  },
});
