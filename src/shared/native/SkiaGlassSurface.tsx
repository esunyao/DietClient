import React from 'react';
import type { NativeSyntheticEvent, ViewProps } from 'react-native';

import NativeSkiaGlassSurface, { type SnapshotPayload } from './SkiaGlassSurfaceNativeComponent';

export type { SnapshotPayload };

export type LiquidCaptureGroup = 'header' | 'tab';

/**
 * SkiaGlassSurface 原生容器（Android/iOS 均为同一 Fabric 组件）。
 * 职责：圆角裁剪、背景捕获（捕获时排除自身子树避免自捕获）、onSnapshot 事件上报。
 * 玻璃的视觉绘制在 SkiaGlassSurface.native.tsx（Skia Canvas）中完成。
 */
export function SkiaGlassSurface({
  children,
  style,
  cornerRadius = 26,
  elevated = false,
  live = false,
  oneShot = false,
  liquidEnabled = false,
  liquidCaptureGroup = 'tab',
  liquidRefractionHeight = 20,
  liquidRefractionOffset = 70,
  liquidBlurRadius = 10,
  liquidDispersion = 0.5,
  onSnapshot,
  ...viewProps
}: ViewProps & {
  cornerRadius?: number;
  elevated?: boolean;
  live?: boolean;
  oneShot?: boolean;
  liquidEnabled?: boolean;
  liquidCaptureGroup?: LiquidCaptureGroup;
  liquidRefractionHeight?: number;
  liquidRefractionOffset?: number;
  liquidBlurRadius?: number;
  liquidDispersion?: number;
  onSnapshot?: (payload: SnapshotPayload) => void;
}) {
  return (
    <NativeSkiaGlassSurface
      cornerRadius={cornerRadius}
      elevated={elevated}
      live={live}
      oneShot={oneShot}
      liquidEnabled={liquidEnabled}
      liquidCaptureGroup={liquidCaptureGroup}
      liquidRefractionHeight={liquidRefractionHeight}
      liquidRefractionOffset={liquidRefractionOffset}
      liquidBlurRadius={liquidBlurRadius}
      liquidDispersion={liquidDispersion}
      // codegen 的 DirectEventHandler 运行时按 NativeSyntheticEvent 包裹
      onSnapshot={(event: NativeSyntheticEvent<SnapshotPayload>) => onSnapshot?.(event.nativeEvent)}
      style={style}
      {...viewProps}
    >
      {children}
    </NativeSkiaGlassSurface>
  );
}
