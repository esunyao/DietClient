import React, { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { BarChart3, Camera, FileText, Home, Sparkles, UserRound } from 'lucide-react-native';

import { GlassSurface } from '../../shared/components/GlassSurface';
import { colors, fonts } from '../../shared/theme/tokens';
import SkiaTabBarChrome from './SkiaTabBarChrome';

const tabMeta = {
  HomeTab: { label: '首页', Icon: Home },
  RecognitionTab: { label: '识别', Icon: Camera },
  MealTab: { label: '配餐', Icon: Sparkles },
  TrendsTab: { label: '趋势', Icon: BarChart3 },
  ReportsTab: { label: '报告', Icon: FileText },
  ProfileTab: { label: '我的', Icon: UserRound },
} as const;

/** 模拟稿的悬浮六项底栏：真实模糊底色 + Skia 光晕 + RN 无障碍按键。 */
export function FrostedTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const [width, setWidth] = useState(0);
  const activeIndex = state.index;
  const chrome = useMemo(() => width ? <SkiaTabBarChrome activeIndex={activeIndex} height={68} width={width} /> : null, [activeIndex, width]);

  return (
    <GlassSurface intensity={52} style={styles.bar}>
      <View onLayout={event => setWidth(event.nativeEvent.layout.width)} style={styles.content}>
        {chrome}
        {state.routes.map((route, index) => {
          const meta = tabMeta[route.name as keyof typeof tabMeta];
          const focused = index === activeIndex;
          const Icon = meta.Icon;
          const options = descriptors[route.key].options;
          const onPress = () => {
            const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
            if (!focused && !event.defaultPrevented) {
              navigation.navigate(route.name);
            }
          };

          return (
            <Pressable
              accessibilityLabel={options.tabBarAccessibilityLabel || meta.label}
              accessibilityRole="button"
              accessibilityState={focused ? { selected: true } : {}}
              key={route.key}
              onLongPress={() => navigation.emit({ type: 'tabLongPress', target: route.key })}
              onPress={onPress}
              style={({ pressed }) => [styles.item, focused && styles.itemFocused, pressed && styles.itemPressed]}
            >
              <Icon color={focused ? colors.blue : '#7A8BA0'} size={20} strokeWidth={focused ? 2.45 : 2.1} />
              <Text style={[styles.label, focused && styles.labelFocused]}>{meta.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </GlassSurface>
  );
}

const styles = StyleSheet.create({
  bar: { position: 'absolute', left: 12, right: 12, bottom: 12, height: 68, borderRadius: 24, boxShadow: '0 12px 28px rgba(58,90,120,0.16)' },
  content: { flex: 1, flexDirection: 'row', alignItems: 'stretch' },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 3, borderRadius: 18, marginVertical: 5 },
  itemFocused: { backgroundColor: 'rgba(255,255,255,0.36)' },
  itemPressed: { opacity: 0.74, transform: [{ scale: 0.96 }] },
  label: { color: '#7A8BA0', fontFamily: fonts.body, fontSize: 10, fontWeight: '700' },
  labelFocused: { color: colors.blue },
});
