import { useEffect } from 'react';
import { AppState } from 'react-native';

import { refreshSessionTokens, useSessionStore } from './sessionStore';

/**
 * 安装应用级会话生命周期：启动时恢复本地会话，回到前台时刷新即将过期的 token。
 * 监听器集中在根导航调用，避免 store 模块在导入时产生无法清理的全局副作用。
 */
export function useSessionLifecycle(): void {
  const hydrate = useSessionStore(state => state.hydrate);

  useEffect(() => {
    hydrate().catch(() => undefined);
  }, [hydrate]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', state => {
      if (state !== 'active') return;
      const tokens = useSessionStore.getState().tokens;
      if (
        tokens?.refreshToken &&
        tokens.obtainedAt + tokens.expiresIn * 1_000 - Date.now() <= 60_000
      ) {
        refreshSessionTokens().catch(() => undefined);
      }
    });
    return () => subscription.remove();
  }, []);
}
