import * as Keychain from 'react-native-keychain';

import type { OidcTokenSet } from '../types/api';
import { parsePersistedTokens, serializeTokens } from './tokenStorageCodec';

const SERVICE = 'com.dietclient.auth.tokens';
const ACCOUNT = 'diet-client';

let currentTokens: OidcTokenSet | null = null;

export const tokenStorage = {
  get: (): OidcTokenSet | null => currentTokens,

  hydrate: async (): Promise<OidcTokenSet | null> => {
    try {
      const credentials = await Keychain.getGenericPassword({ service: SERVICE });
      if (!credentials) {
        currentTokens = null;
        return null;
      }
      const tokens = parsePersistedTokens(credentials.password);
      if (!tokens) {
        await Keychain.resetGenericPassword({ service: SERVICE });
        currentTokens = null;
        return null;
      }
      currentTokens = tokens;
      return tokens;
    } catch {
      currentTokens = null;
      return null;
    }
  },

  save: async (tokens: OidcTokenSet): Promise<void> => {
    await Keychain.setGenericPassword(ACCOUNT, serializeTokens(tokens), { service: SERVICE });
    currentTokens = tokens;
  },

  clear: async (): Promise<void> => {
    try {
      await Keychain.resetGenericPassword({ service: SERVICE });
    } finally {
      currentTokens = null;
    }
  },
};
