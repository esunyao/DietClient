import AsyncStorage from '@react-native-async-storage/async-storage';

import { TOKEN_STORAGE_KEY } from '../config/appConfig';
import type { TokenPair } from '../types/api';

/**
 * Token 同时保存在内存和 AsyncStorage。
 * 请求拦截器读取内存避免每次请求都产生异步存储 I/O，应用重启时再由 hydrate 恢复。
 */
let currentTokens: TokenPair | null = null;

export const tokenStorage = {
  get: (): TokenPair | null => currentTokens,

  hydrate: async (): Promise<TokenPair | null> => {
    const raw = await AsyncStorage.getItem(TOKEN_STORAGE_KEY);
    currentTokens = raw ? (JSON.parse(raw) as TokenPair) : null;
    return currentTokens;
  },

  save: async (tokens: TokenPair): Promise<void> => {
    currentTokens = tokens;
    await AsyncStorage.setItem(TOKEN_STORAGE_KEY, JSON.stringify(tokens));
  },

  clear: async (): Promise<void> => {
    currentTokens = null;
    await AsyncStorage.removeItem(TOKEN_STORAGE_KEY);
  },
};
