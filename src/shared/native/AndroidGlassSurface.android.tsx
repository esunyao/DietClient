import React from 'react';
import type { StyleProp, ViewStyle } from 'react-native';

import NativeAndroidGlassSurface from './AndroidGlassSurfaceNativeComponent';

export function AndroidGlassSurface({
  children,
  style,
  variant,
  elevated = false,
  cornerRadius = 26,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  variant: 'soft' | 'navigation';
  elevated?: boolean;
  cornerRadius?: number;
}) {
  return (
    <NativeAndroidGlassSurface
      cornerRadius={cornerRadius}
      elevated={elevated}
      style={style}
      variant={variant}
    >
      {children}
    </NativeAndroidGlassSurface>
  );
}
