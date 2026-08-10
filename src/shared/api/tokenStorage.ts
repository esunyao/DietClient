import type { OidcTokenSet } from '../types/api';

/**
 * 认证凭证只存在当前 JS 进程内。
 * 不写入 AsyncStorage、Keychain 或其他持久化介质；应用重启后必须重新登录。
 */
let currentTokens: OidcTokenSet | null = null;

export const tokenStorage = {
  get: (): OidcTokenSet | null => currentTokens,

  hydrate: async (): Promise<OidcTokenSet | null> => currentTokens,

  save: async (tokens: OidcTokenSet): Promise<void> => {
    currentTokens = tokens;
  },

  clear: async (): Promise<void> => {
    currentTokens = null;
  },
};
