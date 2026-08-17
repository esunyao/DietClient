import React from 'react';
import type { StyleProp, ViewStyle } from 'react-native';

import NativeAndroidGlassSurface from './AndroidGlassSurfaceNativeComponent';

export function AndroidGlassSurface({
  children,
  style,
  variant,
  elevated = false,
  cornerRadius = 26,
  liquidEnabled = false,
  liquidTouchEffect = false,
  liquidElasticEffect = false,
  liquidCaptureGroup = 'tab',
  liquidRefractionHeight = 20,
  liquidRefractionOffset = 70,
  liquidBlurRadius = 0.01,
  liquidDispersion = 0.5,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  variant: 'soft' | 'navigation';
  elevated?: boolean;
  cornerRadius?: number;
  liquidEnabled?: boolean;
  liquidTouchEffect?: boolean;
  liquidElasticEffect?: boolean;
  liquidCaptureGroup?: 'header' | 'tab';
  liquidRefractionHeight?: number;
  liquidRefractionOffset?: number;
  liquidBlurRadius?: number;
  liquidDispersion?: number;
}) {
  return (
    <NativeAndroidGlassSurface
      cornerRadius={cornerRadius}
      elevated={elevated}
      liquidBlurRadius={liquidBlurRadius}
      liquidDispersion={liquidDispersion}
      liquidElasticEffect={liquidElasticEffect}
      liquidCaptureGroup={liquidCaptureGroup}
      liquidEnabled={liquidEnabled}
      liquidRefractionHeight={liquidRefractionHeight}
      liquidRefractionOffset={liquidRefractionOffset}
      liquidTouchEffect={liquidTouchEffect}
      style={style}
      variant={variant}
    >
      {children}
    </NativeAndroidGlassSurface>
  );
}
