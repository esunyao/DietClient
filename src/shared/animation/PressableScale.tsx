import React from 'react';
import { Pressable, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';

type Props = Omit<PressableProps, 'style'> & {
  /** 静态样式；按压反馈由原生 Pressable 提供。 */
  style?: StyleProp<ViewStyle>;
  /** 按压时的缩放目标（默认 0.98）。 */
  scaleTo?: number;
  /** 按压时的透明度（默认 0.92）。 */
  pressedOpacity?: number;
};

/**
 * 轻量按压反馈。
 * 不为每个可点元素建立 Reanimated 节点，避免 Fabric 页面切换期间的挂载重试。
 */
export function PressableScale({
  children,
  disabled,
  style,
  scaleTo = 0.98,
  pressedOpacity = 0.92,
  onPressIn,
  onPressOut,
  ...rest
}: Props) {
  return (
    <Pressable
      disabled={disabled}
      onPressIn={event => {
        onPressIn?.(event);
      }}
      onPressOut={event => {
        onPressOut?.(event);
      }}
      style={({ pressed }) => [
        style,
        !disabled && pressed && { opacity: pressedOpacity, transform: [{ scale: scaleTo }] },
      ]}
      {...rest}
    >
      {children}
    </Pressable>
  );
}
