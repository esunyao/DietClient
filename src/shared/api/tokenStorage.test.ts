jest.mock('react-native-keychain', () => ({
  getGenericPassword: jest.fn(),
  setGenericPassword: jest.fn(),
  resetGenericPassword: jest.fn(),
}));

import { parsePersistedTokens, serializeTokens } from './tokenStorageCodec';
import { tokenStorage as nativeTokenStorage } from './tokenStorage.native';
import { tokenStorage as webTokenStorage } from './tokenStorage.web';
import * as Keychain from 'react-native-keychain';

const mockKeychain = Keychain as unknown as {
  getGenericPassword: jest.Mock;
  setGenericPassword: jest.Mock;
  resetGenericPassword: jest.Mock;
};

const tokens = {
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'Bearer',
  expiresIn: 300,
  idToken: 'id-token',
  obtainedAt: 1_700_000_000_000,
};

function createWebStorage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
  };
}

describe('token storage adapters', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (globalThis as typeof globalThis & { localStorage?: ReturnType<typeof createWebStorage> }).localStorage = createWebStorage();
    mockKeychain.getGenericPassword.mockResolvedValue(false);
    mockKeychain.setGenericPassword.mockResolvedValue({ service: 'com.dietclient.auth.tokens' });
    mockKeychain.resetGenericPassword.mockResolvedValue(true);
  });

  it('validates persisted token shape and removes malformed values', () => {
    expect(parsePersistedTokens(serializeTokens(tokens))).toEqual(tokens);
    expect(parsePersistedTokens('{"accessToken":"only-access"}')).toBeNull();
    expect(parsePersistedTokens('not-json')).toBeNull();
  });

  it('persists and hydrates Web credentials, then clears them', async () => {
    await webTokenStorage.save(tokens);
    expect(await webTokenStorage.hydrate()).toEqual(tokens);
    await webTokenStorage.clear();
    expect(await webTokenStorage.hydrate()).toBeNull();
  });

  it('degrades safely when Web storage is unavailable', async () => {
    delete (globalThis as typeof globalThis & { localStorage?: unknown }).localStorage;
    await expect(webTokenStorage.save(tokens)).resolves.toBeUndefined();
    await expect(webTokenStorage.clear()).resolves.toBeUndefined();
  });

  it('persists and hydrates native credentials through Keychain/Keystore', async () => {
    await nativeTokenStorage.save(tokens);
    expect(mockKeychain.setGenericPassword).toHaveBeenCalledWith('diet-client', JSON.stringify(tokens), { service: 'com.dietclient.auth.tokens' });
    mockKeychain.getGenericPassword.mockResolvedValue({ username: 'diet-client', password: JSON.stringify(tokens) });
    expect(await nativeTokenStorage.hydrate()).toEqual(tokens);
    await nativeTokenStorage.clear();
    expect(mockKeychain.resetGenericPassword).toHaveBeenCalledWith({ service: 'com.dietclient.auth.tokens' });
  });

  it('clears malformed native credentials before returning signed out', async () => {
    mockKeychain.getGenericPassword.mockResolvedValue({ username: 'diet-client', password: '{"accessToken":"bad"}' });
    expect(await nativeTokenStorage.hydrate()).toBeNull();
    expect(mockKeychain.resetGenericPassword).toHaveBeenCalledWith({ service: 'com.dietclient.auth.tokens' });
  });
});
