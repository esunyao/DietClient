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
  /** 头像对象键不可直接用于 <Image>，这里只保存 GET /v1/files/avatar 返回的展示 URL。 */
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
  // 用户与画像没有依赖关系，并发读取可缩短登录后首屏等待时间。
  const profileRequest = userApi.getProfile().then(
    profile => ({ profile, profileMissing: false }),
    error => {
      if (isProfileNotFound(error)) {
        return { profile: null, profileMissing: true };
      }
      throw error;
    },
  );
  const user = await userApi.getSelf();
  const profileResult = await profileRequest;

  if (!user.avatarUrl) {
    return { user, ...profileResult, avatarPreviewUrl: null };
  }

  // 后端更新头像对象键时才重新换取预签名展示 URL，避免每次进入“我的”都多一次网络请求。
  if (previous?.user?.avatarUrl === user.avatarUrl && previous.avatarPreviewUrl) {
    return { user, ...profileResult, avatarPreviewUrl: previous.avatarPreviewUrl };
  }

  try {
    const avatarPreviewUrl = /^https?:\/\//.test(user.avatarUrl) ? user.avatarUrl : await userApi.getAvatarUrl();
    return { user, ...profileResult, avatarPreviewUrl };
  } catch {
    // 头像读取失败不应阻断账户资料；Avatar 组件会稳定回退为昵称渐变头像。
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
      avatarPreviewUrl: null,
      profileMissing: false,
      error: null,
    });
  },
}));

// 刷新 Token 失败由网络层通知此处，导航会根据 status 自动回到登录页。
setSessionInvalidHandler(() => {
  useSessionStore.getState().clearLocalSession().catch(() => undefined);
});
