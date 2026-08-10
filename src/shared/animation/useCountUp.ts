import { useEffect, useRef, useState } from 'react';

import { durations } from './config';

/**
 * 跨端数字滚动 hook：rAF + ease-out，约 duration 毫秒从 0 滚到 target。
 * Web 端 reanimated 无法驱动 `Text` 的 textContent（只更新 attribute），
 * 因此统一用 JS rAF 实现，原生与 Web 行为一致、确定性高；
 * 每次数字仅触发约几十次轻量重渲染，可接受。
 */
export function useCountUp(target: number, duration = durations.countUp): string {
  const [display, setDisplay] = useState(0);
  const frame = useRef<number | null>(null);

  useEffect(() => {
    const start = Date.now();
    const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);

    const tick = () => {
      const elapsed = Date.now() - start;
      const progress = Math.min(elapsed / duration, 1);
      setDisplay(Math.round(target * easeOut(progress)));
      if (progress < 1) {
        frame.current = requestAnimationFrame(tick);
      }
    };

    frame.current = requestAnimationFrame(tick);
    return () => {
      if (frame.current !== null) {
        cancelAnimationFrame(frame.current);
      }
    };
  }, [target, duration]);

  return String(display);
}
