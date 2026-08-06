import axios from 'axios';
import { create } from 'zustand';

import { ApiError, getErrorMessage, setSessionInvalidHandler } from '../../../shared/api/client';
import { tokenStorage } from '../../../shared/api/tokenStorage';
import type { LoginPayload, RegisterPayload, TokenPair, User, UserProfile } from '../../../shared/types/api';
import { userApi } from '../../profile/api/userApi';
import { authApi } from '../api/authApi';

type SessionStatus = 'restoring' | 'signedOut' | 'signedIn';

interface SessionState {
  status: SessionStatus;
  tokens: TokenPair | null;
  user: User | null;
  profile: UserProfile | null;
  profileMissing: boolean;
  error: string | null;
  hydrate: () => Promise<void>;
  signIn: (payload: LoginPayload) => Promise<void>;
  register: (payload: RegisterPayload) => Promise<void>;
  refreshUserData: () => Promise<void>;
  setUser: (user: User) => void;
  setProfile: (profile: UserProfile) => void;
  signOut: () => Promise<void>;
  clearLocalSession: () => Promise<void>;
}

function isProfileNotFound(error: unknown): boolean {
  return (error instanceof ApiError && error.code === 404) ||
    (axios.isAxiosError(error) && error.response?.status === 404);
}

async function loadUserData(): Promise<{ user: User; profile: UserProfile | null; profileMissing: boolean }> {
  const user = await userApi.getSelf();

  try {
    const profile = await userApi.getProfile();
    return { user, profile, profileMissing: false };
  } catch (error) {
    if (isProfileNotFound(error)) {
      return { user, profile: null, profileMissing: true };
    }
    throw error;
  }
}

export const useSessionStore = create<SessionState>((set, get) => ({
  status: 'restoring',
  tokens: null,
  user: null,
  profile: null,
  profileMissing: false,
  error: null,

  hydrate: async () => {
    set({ status: 'restoring', error: null });
    const tokens = await tokenStorage.hydrate();

    if (!tokens) {
      set({ status: 'signedOut' });
      return;
    }

    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data });
    } catch (error) {
      await tokenStorage.clear();
      set({ status: 'signedOut', tokens: null, error: getErrorMessage(error) });
    }
  },

  signIn: async payload => {
    const tokens = await authApi.login(payload);
    await tokenStorage.save(tokens);

    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data, error: null });
    } catch (error) {
      await tokenStorage.clear();
      set({ status: 'signedOut', tokens: null, error: getErrorMessage(error) });
      throw error;
    }
  },

  register: async payload => {
    await authApi.register(payload);
  },

  refreshUserData: async () => {
    const data = await loadUserData();
    set(data);
  },

  setUser: user => set({ user }),
  setProfile: profile => set({ profile, profileMissing: false }),

  signOut: async () => {
    const refreshToken = get().tokens?.refreshToken;

    try {
      if (refreshToken) {
        await authApi.logout(refreshToken);
      }
    } catch {
      // 登出接口不可用时也必须清除本地凭证，避免失效会话停留在应用中。
    } finally {
      await get().clearLocalSession();
    }
  },

  clearLocalSession: async () => {
    await tokenStorage.clear();
    set({
      status: 'signedOut',
      tokens: null,
      user: null,
      profile: null,
      profileMissing: false,
      error: null,
    });
  },
}));

// 刷新 Token 失败由网络层通知此处，导航会根据 status 自动回到登录页。
setSessionInvalidHandler(() => {
  useSessionStore.getState().clearLocalSession().catch(() => undefined);
});
