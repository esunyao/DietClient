import axios from 'axios';
import { create } from 'zustand';

import { ApiError, getErrorMessage, setApiAccessToken, setSessionInvalidHandler } from '../../../shared/api/client';
import { tokenStorage } from '../../../shared/api/tokenStorage';
import type { OidcTokenSet, User, UserProfile } from '../../../shared/types/api';
import { userApi } from '../../profile/api/userApi';
import { authApi, type LoginPayload, type RegisterPayload } from '../api/authApi';

type SessionStatus = 'restoring' | 'signedOut' | 'signedIn';

interface SessionState {
  status: SessionStatus;
  tokens: OidcTokenSet | null;
  user: User | null;
  profile: UserProfile | null;
  avatarPreviewUrl: string | null;
  profileMissing: boolean;
  error: string | null;
  hydrate: () => Promise<void>;
  signIn: (payload: LoginPayload) => Promise<void>;
  register: (payload: RegisterPayload) => Promise<void>;
  refreshUserData: () => Promise<void>;
  setUser: (user: User) => void;
  setProfile: (profile: UserProfile) => void;
  setAvatarPreviewUrl: (url: string | null) => void;
  signOut: () => Promise<void>;
  clearLocalSession: () => Promise<void>;
}

function isProfileNotFound(error: unknown): boolean {
  return (error instanceof ApiError && error.code === 404) ||
    (axios.isAxiosError(error) && error.response?.status === 404);
}

async function loadUserData(previous?: Pick<SessionState, 'user' | 'avatarPreviewUrl'>): Promise<{
  user: User;
  profile: UserProfile | null;
  profileMissing: boolean;
  avatarPreviewUrl: string | null;
}> {
  const profileRequest = userApi.getProfile().then(
    profile => ({ profile, profileMissing: false }),
    error => {
      if (isProfileNotFound(error)) {
        return { profile: null, profileMissing: true };
      }
      throw error;
    },
  );
  const [user, profileResult] = await Promise.all([userApi.getSelf(), profileRequest]);

  if (!user.avatarUrl) {
    return { user, ...profileResult, avatarPreviewUrl: null };
  }
  if (previous?.user?.avatarUrl === user.avatarUrl && previous.avatarPreviewUrl) {
    return { user, ...profileResult, avatarPreviewUrl: previous.avatarPreviewUrl };
  }
  try {
    const avatarPreviewUrl = /^https?:\/\//.test(user.avatarUrl) ? user.avatarUrl : await userApi.getAvatarUrl();
    return { user, ...profileResult, avatarPreviewUrl };
  } catch {
    return { user, ...profileResult, avatarPreviewUrl: null };
  }
}

export const useSessionStore = create<SessionState>((set, get) => ({
  status: 'restoring',
  tokens: null,
  user: null,
  profile: null,
  avatarPreviewUrl: null,
  profileMissing: false,
  error: null,

  hydrate: async () => {
    set({ status: 'restoring', error: null });
    const tokens = await tokenStorage.hydrate();
    if (!tokens) {
      setApiAccessToken(null);
      set({ status: 'signedOut' });
      return;
    }
    setApiAccessToken(tokens.accessToken);
    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data });
    } catch (error) {
      await tokenStorage.clear();
      setApiAccessToken(null);
      set({ status: 'signedOut', tokens: null, error: getErrorMessage(error) });
    }
  },

  signIn: async payload => {
    const tokens = await authApi.login(payload);
    await tokenStorage.save(tokens);
    setApiAccessToken(tokens.accessToken);
    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data, error: null });
    } catch (error) {
      await tokenStorage.clear();
      setApiAccessToken(null);
      set({ status: 'signedOut', tokens: null, error: getErrorMessage(error) });
      throw error;
    }
  },

  register: async payload => {
    await authApi.register(payload);
  },

  refreshUserData: async () => {
    const data = await loadUserData(get());
    set(data);
  },

  setUser: user => set(state => ({
    user,
    avatarPreviewUrl: state.user?.avatarUrl === user.avatarUrl ? state.avatarPreviewUrl : null,
  })),
  setProfile: profile => set({ profile, profileMissing: false }),
  setAvatarPreviewUrl: avatarPreviewUrl => set({ avatarPreviewUrl }),

  signOut: async () => {
    await get().clearLocalSession();
  },

  clearLocalSession: async () => {
    await tokenStorage.clear();
    setApiAccessToken(null);
    set({
      status: 'signedOut',
      tokens: null,
      user: null,
      profile: null,
      avatarPreviewUrl: null,
      profileMissing: false,
      error: null,
    });
  },
}));

setSessionInvalidHandler(() => {
  useSessionStore.getState().clearLocalSession().catch(() => undefined);
});
