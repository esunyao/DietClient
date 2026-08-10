import React from 'react';
import { Pressable, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from 'react-native-reanimated';

import { durations, springSnappy } from './config';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

type Props = Omit<PressableProps, 'style'> & {
  /** 静态样式；按压反馈由内部弹簧接管，不再需要 `({ pressed }) => …`。 */
  style?: StyleProp<ViewStyle>;
  /** 按压时的缩放目标（默认 0.96）。 */
  scaleTo?: number;
  /** 按压时的透明度（默认 0.82）。 */
  pressedOpacity?: number;
};

/**
 * 通用按压弹簧反馈，全部动画跑在 reanimated（UI 线程 / Web 合成器）。
 * 替换各处的 `pressed && styles.pressed` 静态样式，按压手感更跟手。
 */
export function PressableScale({
  children,
  disabled,
  style,
  scaleTo = 0.96,
  pressedOpacity = 0.82,
  onPressIn,
  onPressOut,
  ...rest
}: Props) {
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  return (
    <AnimatedPressable
      disabled={disabled}
      onPressIn={event => {
        if (!disabled) {
          scale.value = withSpring(scaleTo, springSnappy);
          opacity.value = withTiming(pressedOpacity, { duration: durations.pressFade });
        }
        onPressIn?.(event);
      }}
      onPressOut={event => {
        if (!disabled) {
          scale.value = withSpring(1, springSnappy);
          opacity.value = withTiming(1, { duration: durations.pressFade });
        }
        onPressOut?.(event);
      }}
      style={[style, animatedStyle]}
      {...rest}
    >
      {children}
    </AnimatedPressable>
  );
}
