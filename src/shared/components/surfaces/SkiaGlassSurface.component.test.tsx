import React from 'react';
import { Platform, View } from 'react-native';
import { act, create } from 'react-test-renderer';

import { SkiaGlassSurface as SkiaGlassSurfaceWrapper } from '../../native/SkiaGlassSurface';
import { SkiaGlassSurface } from './SkiaGlassSurface.native';
import * as SnapshotFrameModule from './SkiaGlassSnapshotFrame';

/**
 * 组件级冒烟测试：依赖 moduleNameMapper 的轻量 mock
 * （@shopify/react-native-skia / react-native-reanimated / 原生容器组件）。
 * 固定 Platform.OS = android 跳过 iOS AccessibilityInfo 副作用。
 */
describe('SkiaGlassSurface 组件', () => {
  beforeAll(() => {
    Platform.OS = 'android';
  });

  it('soft 变体渲染纯静态层，不挂原生捕获容器', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface variant="soft">
          <View testID="child" />
        </SkiaGlassSurface>,
      );
    });
    expect(() => tree!.root.findByType(SkiaGlassSurfaceWrapper)).toThrow();
    expect(tree!.root.findByProps({ testID: 'child' })).toBeTruthy();
    act(() => tree!.unmount());
  });

  it('navigation 变体渲染原生捕获容器与子节点', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface
          captureGroup="header"
          variant="navigation"
          cornerRadius={20}
          intensity={50}
        >
          <View testID="child" />
        </SkiaGlassSurface>,
      );
    });
    const host = tree!.root.findByType(SkiaGlassSurfaceWrapper);
    expect(host.props.cornerRadius).toBe(20);
    expect(host.props.live).toBe(true);
    expect(host.props.liquidEnabled).toBe(false);
    expect(host.props.liquidCaptureGroup).toBe('header');
    expect(tree!.root.findByProps({ testID: 'child' })).toBeTruthy();
    act(() => tree!.unmount());
  });

  it('不可见的导航层可以显式停止背景捕获', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface capture={false} variant="navigation">
          <View />
        </SkiaGlassSurface>,
      );
    });
    expect(tree!.root.findByType(SkiaGlassSurfaceWrapper).props.live).toBe(false);
    act(() => tree!.unmount());
  });

  it('liquid 开启时透传液态参数到原生容器', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface
          variant="navigation"
          liquid={{
            enabled: true,
            touchEffect: true,
            elasticEffect: true,
            captureGroup: 'tab',
            refractionHeight: 21,
            refractionOffset: 60,
            blurRadius: 10,
            dispersion: 0.8,
          }}
        >
          <View />
        </SkiaGlassSurface>,
      );
    });
    const host = tree!.root.findByType(SkiaGlassSurfaceWrapper);
    expect(host.props.liquidEnabled).toBe(true);
    expect(host.props.liquidCaptureGroup).toBe('tab');
    expect(host.props.liquidRefractionHeight).toBe(21);
    expect(host.props.liquidDispersion).toBe(0.8);
    act(() => tree!.unmount());
  });

  it('快照事件按 version 去重并触发图像重建（不抛错）', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface variant="frosted">
          <View />
        </SkiaGlassSurface>,
      );
    });
    const host = tree!.root.findByType(SkiaGlassSurfaceWrapper);
    const payload = {
      jpeg: 'aGVsbG8=', // base64("hello")，mock 解码器直接透传
      width: 180,
      height: 60,
      sourceOffsetX: 0,
      sourceOffsetY: 0,
      contentScale: 0.5,
      version: 1,
    };
    act(() => {
      host.props.onSnapshot(payload);
      // 相同 version 去重
      host.props.onSnapshot(payload);
      // 新 version 更新
      host.props.onSnapshot({ ...payload, version: 2 });
    });
    expect(tree!.root.findByType(SkiaGlassSurfaceWrapper)).toBeTruthy();
    act(() => tree!.unmount());
  });

  it('非液态快照带非零 sourceOffset 时被陈旧帧守卫拒绝（不绘制残影）', () => {
    const spy = jest.spyOn(SnapshotFrameModule, 'normalizeSnapshotFrame');
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface variant="navigation">
          <View />
        </SkiaGlassSurface>,
      );
    });
    const host = tree!.root.findByType(SkiaGlassSurfaceWrapper);
    try {
      act(() => {
        // 玻璃移动后旧位图以新偏移投递（如 tabbar translateY 显隐）
        host.props.onSnapshot({
          jpeg: 'aGVsbG8=',
          width: 180,
          height: 60,
          sourceOffsetX: 66,
          sourceOffsetY: 66,
          contentScale: 0.5,
          version: 3,
        });
      });
      const results = spy.mock.results.filter(result => result.type === 'return');
      expect(results.length).toBeGreaterThan(0);
      expect(results[results.length - 1].value).toBeNull();
    } finally {
      spy.mockRestore();
      act(() => tree!.unmount());
    }
  });

  it('收到无效快照时回退到实体材质（不抛错）', () => {
    let tree: ReturnType<typeof create>;
    act(() => {
      tree = create(
        <SkiaGlassSurface variant="navigation">
          <View />
        </SkiaGlassSurface>,
      );
    });
    const host = tree!.root.findByType(SkiaGlassSurfaceWrapper);
    expect(() =>
      act(() =>
        host.props.onSnapshot({
          jpeg: '',
          width: 0,
          height: 0,
          sourceOffsetX: 0,
          sourceOffsetY: 0,
          contentScale: 0,
          version: -1,
        }),
      ),
    ).not.toThrow();
    act(() => tree!.unmount());
  });

  it('iOS 直接使用 Skia 组件时回退实体材质且不注册捕获', () => {
    const previousPlatform = Platform.OS;
    Platform.OS = 'ios';
    let tree: ReturnType<typeof create> | undefined;
    try {
      act(() => {
        tree = create(
          <SkiaGlassSurface variant="navigation">
            <View testID="ios-fallback-child" />
          </SkiaGlassSurface>,
        );
      });
      expect(() => tree!.root.findByType(SkiaGlassSurfaceWrapper)).toThrow();
      expect(tree!.root.findByProps({ testID: 'ios-fallback-child' })).toBeTruthy();
    } finally {
      act(() => tree?.unmount());
      Platform.OS = previousPlatform;
    }
  });
});
