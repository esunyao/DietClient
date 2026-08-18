import type { OidcTokenSet } from '../types/api';
import { parsePersistedTokens, serializeTokens } from './tokenStorageCodec';

const STORAGE_KEY = 'diet.auth.tokens.v1';

let currentTokens: OidcTokenSet | null = null;

interface WebStorage {
  getItem: (key: string) => string | null;
  setItem: (key: string, value: string) => void;
  removeItem: (key: string) => void;
}

function storage(): WebStorage | null {
  try {
    const runtime = globalThis as typeof globalThis & { localStorage?: WebStorage };
    return runtime.localStorage ?? null;
  } catch {
    return null;
  }
}

export const tokenStorage = {
  get: (): OidcTokenSet | null => currentTokens,

  hydrate: async (): Promise<OidcTokenSet | null> => {
    const target = storage();
    if (!target) return currentTokens;
    const tokens = parsePersistedTokens(target.getItem(STORAGE_KEY));
    if (tokens) {
      currentTokens = tokens;
      return tokens;
    }
    if (target.getItem(STORAGE_KEY) !== null) target.removeItem(STORAGE_KEY);
    currentTokens = null;
    return null;
  },

  save: async (tokens: OidcTokenSet): Promise<void> => {
    const target = storage();
    if (target) target.setItem(STORAGE_KEY, serializeTokens(tokens));
    currentTokens = tokens;
  },

  clear: async (): Promise<void> => {
    const target = storage();
    if (target) target.removeItem(STORAGE_KEY);
    currentTokens = null;
  },
};
