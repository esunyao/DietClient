import axios from 'axios';
import { create } from 'zustand';
import { AppState } from 'react-native';

import { ApiError, getErrorMessage, refreshApiTokens, setApiAccessToken, setSessionInvalidHandler, setTokensRefreshedHandler } from '../../../shared/api/client';
import { tokenStorage } from '../../../shared/api/tokenStorage';
import type { OidcTokenSet, User, UserProfile } from '../../../shared/types/api';
import { userApi } from '../../profile/api/userApi';
import { authApi, type LoginPayload, type RegisterPayload, type RegistrationResult } from '../api/authApi';
import { profileOnboardingStorage } from '../services/profileOnboardingStorage';

type SessionStatus = 'restoring' | 'signedOut' | 'signedIn';

interface SessionState {
  status: SessionStatus;
  tokens: OidcTokenSet | null;
  user: User | null;
  profile: UserProfile | null;
  avatarPreviewUrl: string | null;
  profileMissing: boolean;
  onboardingResolved: boolean;
  profileOnboardingRequired: boolean;
  error: string | null;
  hydrate: () => Promise<void>;
  signIn: (payload: LoginPayload) => Promise<void>;
  register: (payload: RegisterPayload) => Promise<RegistrationResult>;
  resendVerificationEmail: (email: string) => Promise<void>;
  refreshUserData: () => Promise<void>;
  setUser: (user: User) => void;
  setProfile: (profile: UserProfile) => void;
  completeProfileOnboarding: () => Promise<void>;
  setAvatarPreviewUrl: (url: string | null) => void;
  signOut: () => Promise<void>;
  clearLocalSession: () => Promise<void>;
}

let refreshTimer: ReturnType<typeof setTimeout> | null = null;

function clearRefreshTimer(): void {
  if (refreshTimer) clearTimeout(refreshTimer);
  refreshTimer = null;
}

function scheduleRefresh(set: (state: Partial<SessionState>) => void, tokens: OidcTokenSet): void {
  clearRefreshTimer();
  if (!tokens.refreshToken) return;
  const delay = Math.max(1_000, tokens.obtainedAt + tokens.expiresIn * 1_000 - Date.now() - 60_000);
  refreshTimer = setTimeout(() => {
    refreshApiTokens()
      .then(next => {
        set({ tokens: next });
        scheduleRefresh(set, next);
      })
      .catch(() => undefined);
  }, delay);
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
  // Orion 会在首次访问 self 时按 OIDC 身份建立业务用户。新账号若同时请求
  // self 和 profile，两条请求会竞争创建同一用户，其中一条返回 409
  // “用户名或邮箱已关联其他业务用户”。必须先完成 self，再读取档案。
  const user = await userApi.getSelf();
  const profileResult = await userApi.getProfile().then(
    profile => ({ profile, profileMissing: false }),
    error => {
      if (isProfileNotFound(error)) {
        return { profile: null, profileMissing: true };
      }
      throw error;
    },
  );

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

async function loadOnboardingState(user: User): Promise<Pick<SessionState, 'onboardingResolved' | 'profileOnboardingRequired'>> {
  // “首次注册”与“档案字段是否填齐”是两件事。只有本机刚完成注册的
  // 账号会进入一次引导；profileCompletedAt 只用于页面上的完整度提示。
  const alreadyCompleted = await profileOnboardingStorage.hasCompleted(user.userId);
  const profileOnboardingRequired = !alreadyCompleted && await profileOnboardingStorage.consumePendingFor(user);
  return { onboardingResolved: true, profileOnboardingRequired };
}

export const useSessionStore = create<SessionState>((set, get) => ({
  status: 'restoring',
  tokens: null,
  user: null,
  profile: null,
  avatarPreviewUrl: null,
  profileMissing: false,
  onboardingResolved: false,
  profileOnboardingRequired: false,
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
    scheduleRefresh(set, tokens);
    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data, ...(await loadOnboardingState(data.user)) });
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
    scheduleRefresh(set, tokens);
    try {
      const data = await loadUserData();
      set({ status: 'signedIn', tokens, ...data, ...(await loadOnboardingState(data.user)), error: null });
    } catch (error) {
      await tokenStorage.clear();
      setApiAccessToken(null);
      set({ status: 'signedOut', tokens: null, error: getErrorMessage(error) });
      throw error;
    }
  },

  register: async payload => {
    const result = await authApi.register(payload);
    await profileOnboardingStorage.markRegistrationPending(result.username, result.email);
    return result;
  },

  resendVerificationEmail: async email => {
    await authApi.resendVerificationEmail(email);
  },

  refreshUserData: async () => {
    const data = await loadUserData(get());
    set({ ...data });
  },

  setUser: user => set(state => ({
    user,
    avatarPreviewUrl: state.user?.avatarUrl === user.avatarUrl ? state.avatarPreviewUrl : null,
  })),
  setProfile: profile => set({ profile, profileMissing: false }),
  completeProfileOnboarding: async () => {
    const userId = get().user?.userId;
    if (userId) await profileOnboardingStorage.complete(userId);
    set({ onboardingResolved: true, profileOnboardingRequired: false });
  },
  setAvatarPreviewUrl: avatarPreviewUrl => set({ avatarPreviewUrl }),

  signOut: async () => {
    await get().clearLocalSession();
  },

  clearLocalSession: async () => {
    clearRefreshTimer();
    await tokenStorage.clear();
    setApiAccessToken(null);
    set({
      status: 'signedOut',
      tokens: null,
      user: null,
      profile: null,
      avatarPreviewUrl: null,
      profileMissing: false,
      onboardingResolved: false,
      profileOnboardingRequired: false,
      error: null,
    });
  },
}));

setSessionInvalidHandler(() => {
  useSessionStore.getState().clearLocalSession().catch(() => undefined);
});

setTokensRefreshedHandler(tokens => {
  useSessionStore.setState({ tokens });
  scheduleRefresh(useSessionStore.setState, tokens);
});

AppState.addEventListener('change', state => {
  if (state !== 'active') return;
  const tokens = useSessionStore.getState().tokens;
  if (tokens?.refreshToken && tokens.obtainedAt + tokens.expiresIn * 1_000 - Date.now() <= 60_000) {
    refreshApiTokens().catch(() => undefined);
  }
});
