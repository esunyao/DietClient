import React from 'react';
import { Pressable, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';

import { durations, springPress, timing } from './config';

type Props = Omit<PressableProps, 'style'> & {
  /** 静态样式；反馈由 UI 线程完成。 */
  style?: StyleProp<ViewStyle>;
  /** 按压时的缩放目标（默认 0.98）。 */
  scaleTo?: number;
  /** 按压时的透明度（默认 0.92）。 */
  pressedOpacity?: number;
};

/**
 * 轻量按压反馈。仅改 transform 与 opacity，不触发布局或 React 重渲染。
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
  const press = useSharedValue(0);
  const animatedStyle = useAnimatedStyle(() => ({
    opacity: 1 - (1 - pressedOpacity) * press.value,
    transform: [{ scale: 1 - (1 - scaleTo) * press.value }],
  }));

  return (
    <AnimatedPressable
      disabled={disabled}
      onPressIn={event => {
        press.value = withTiming(1, timing(durations.pressIn));
        onPressIn?.(event);
      }}
      onPressOut={event => {
        press.value = withSpring(0, springPress);
        onPressOut?.(event);
      }}
      style={[style, animatedStyle]}
      {...rest}
    >
      {children}
    </AnimatedPressable>
  );
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);
