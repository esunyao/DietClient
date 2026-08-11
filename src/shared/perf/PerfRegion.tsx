import React, { Profiler, type ProfilerOnRenderCallback, type ReactNode } from 'react';

/**
 * 渲染耗时标注（仅 dev）。
 *
 * 用 React Profiler 记录标注区域内每次 commit 的实际渲染耗时，输出到 console，
 * 便于精确定位"哪个模块"导致渲染堵塞，格式：
 *   [perf] ScreenHeader update 12.3ms
 *
 * release 构建下直接透传 children，不挂载 Profiler，零运行时开销。
 */
export function PerfRegion({ name, children }: { name: string; children: ReactNode }) {
  if (!__DEV__) {
    return <>{children}</>;
  }

  const onRender: ProfilerOnRenderCallback = (_id, phase, actualDuration) => {
    // 只输出耗时 > 0.5ms 的 commit，避免每次 setState 都刷一行噪音。
    if (actualDuration > 0.5) {
      console.log(`[perf] ${name} ${phase} ${actualDuration.toFixed(1)}ms`);
    }
  };

  return (
    <Profiler id={name} onRender={onRender}>
      {children}
    </Profiler>
  );
}
