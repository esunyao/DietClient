import React from 'react';
import { View, type StyleProp, type ViewStyle } from 'react-native';

export function AndroidGlassSurface({ children, style }: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  variant: 'soft' | 'navigation';
  elevated?: boolean;
  cornerRadius?: number;
}) {
  return <View style={style}>{children}</View>;
}
