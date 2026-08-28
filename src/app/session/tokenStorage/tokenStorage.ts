import type { OidcTokenSet } from '../../../features/auth/api/authTypes';

/** 非原生/非 Web 环境的内存回退；平台构建会解析 tokenStorage.native/web。 */
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
