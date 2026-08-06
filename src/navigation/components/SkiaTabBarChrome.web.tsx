import React from 'react';
import { WithSkiaWeb } from '@shopify/react-native-skia/lib/module/web';

type Props = { width: number; height: number; activeIndex: number };

/** Web 首次访问底栏时才下载 CanvasKit，避免登录页承担约 3 MB 的图形运行时。 */
export default function SkiaTabBarChrome(props: Props) {
  return (
    <WithSkiaWeb
      componentProps={props}
      fallback={null}
      getComponent={() => import('./SkiaTabBarChrome.canvas')}
      opts={{ locateFile: file => `/${file}` }}
    />
  );
}
