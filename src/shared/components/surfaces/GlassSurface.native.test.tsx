import React from 'react';
import { Platform, View } from 'react-native';
import { act, create } from 'react-test-renderer';

import { SkiaGlassSurface as SkiaGlassSurfaceNative } from '../../native/SkiaGlassSurface';
import { GlassSurface } from './GlassSurface.native';

jest.mock('@sbaiahmed1/react-native-blur', () => {
  const { View: NativeView } = require('react-native');
  return {
    BlurView: ({ children, ...props }: { children?: React.ReactNode }) => (
      <NativeView testID="native-blur-view" {...props}>
        {children}
      </NativeView>
    ),
  };
});

describe('GlassSurface native material routing', () => {
  it('uses the native iOS material for navigation without a Skia host', () => {
    const previousPlatform = Platform.OS;
    Platform.OS = 'ios';
    let tree: ReturnType<typeof create> | undefined;
    try {
      act(() => {
        tree = create(
          <GlassSurface variant="navigation">
            <View testID="content" />
          </GlassSurface>,
        );
      });
      expect(tree!.root.findByProps({ testID: 'native-blur-view' })).toBeTruthy();
      expect(() => tree!.root.findByType(SkiaGlassSurfaceNative)).toThrow();
    } finally {
      act(() => tree?.unmount());
      Platform.OS = previousPlatform;
    }
  });

  it('uses the native iOS material for frosted surfaces as well', () => {
    const previousPlatform = Platform.OS;
    Platform.OS = 'ios';
    let tree: ReturnType<typeof create> | undefined;
    try {
      act(() => {
        tree = create(
          <GlassSurface variant="frosted">
            <View />
          </GlassSurface>,
        );
      });
      expect(tree!.root.findByProps({ testID: 'native-blur-view' })).toBeTruthy();
    } finally {
      act(() => tree?.unmount());
      Platform.OS = previousPlatform;
    }
  });
});
