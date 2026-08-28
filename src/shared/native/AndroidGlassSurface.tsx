import React from 'react';
import { View, type StyleProp, type ViewStyle } from 'react-native';

/** TypeScript fallback; Metro selects the Android/iOS implementation at runtime. */
export function AndroidGlassSurface({
  children,
  style,
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
  return <View style={style}>{children}</View>;
}
