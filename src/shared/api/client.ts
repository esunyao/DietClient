import axios, { AxiosError, AxiosHeaders, type AxiosRequestConfig, type AxiosResponse } from 'axios';

import { refreshAccessToken } from '../../features/auth/api/authApi';
import { API_BASE_URL } from '../config/appConfig';
import type { ApiEnvelope, OidcTokenSet } from '../types/api';
import { tokenStorage } from './tokenStorage';

type RetriableRequest = AxiosRequestConfig & { _hasRetried?: boolean };

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly code?: number,
    public readonly traceId?: string | null,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export function unwrapApiResponse<T>(response: AxiosResponse<ApiEnvelope<T>>): T {
  const envelope = response.data;
  if (envelope.code !== 200 || envelope.data === null) {
    throw new ApiError(envelope.message || '请求未完成，请稍后重试', envelope.code, envelope.traceId);
  }
  return envelope.data;
}

export function assertApiSuccess(response: AxiosResponse<ApiEnvelope<unknown>>): void {
  const envelope = response.data;
  if (envelope.code !== 200) {
    throw new ApiError(envelope.message || '请求未完成，请稍后重试', envelope.code, envelope.traceId);
  }
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message;
  }
  if (axios.isAxiosError(error)) {
    const body = error.response?.data as Record<string, unknown> | undefined;
    const message = body?.message || body?.detail || body?.error_description;
    return (typeof message === 'string' ? message : undefined) || error.message || '网络连接失败，请检查服务是否已启动';
  }
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return '操作未完成，请稍后重试';
}

const rawClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 12_000,
  headers: { 'Content-Type': 'application/json' },
});

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 12_000,
  headers: { 'Content-Type': 'application/json' },
});

let refreshInFlight: Promise<OidcTokenSet> | null = null;
let onSessionInvalid: (() => void) | null = null;
let activeAccessToken: string | null = null;

export function buildAuthorizationHeader(accessToken?: string): Record<string, string> {
  return accessToken ? { Authorization: `Bearer ${accessToken}` } : {};
}

/**
 * 认证成功或刷新成功后同步 Axios 实例的默认请求头。
 *
 * tokenStorage 仍是唯一的凭证存储；该值只是避免 React Native 热更新/请求调度边界
 * 让首个业务请求错过拦截器注入。
 */
export function setApiAccessToken(accessToken: string | null): void {
  activeAccessToken = accessToken;
  if (accessToken) {
    apiClient.defaults.headers.common.Authorization = `Bearer ${accessToken}`;
    return;
  }
  delete apiClient.defaults.headers.common.Authorization;
}

export function shouldRefreshAfterUnauthorized(status?: number, request?: RetriableRequest): boolean {
  return status === 401 && Boolean(request) && !request?._hasRetried;
}

export function setSessionInvalidHandler(handler: () => void): void {
  onSessionInvalid = handler;
}

async function refreshTokens(): Promise<OidcTokenSet> {
  const nextTokens = await refreshAccessToken();
  await tokenStorage.save(nextTokens);
  setApiAccessToken(nextTokens.accessToken);
  return nextTokens;
}

apiClient.interceptors.request.use(config => {
  const accessToken = activeAccessToken || tokenStorage.get()?.accessToken;
  if (accessToken) {
    config.headers = config.headers || new AxiosHeaders();
    config.headers.set('Authorization', buildAuthorizationHeader(accessToken).Authorization);
  }
  return config;
});

apiClient.interceptors.response.use(
  response => response,
  async (error: AxiosError<ApiEnvelope<unknown>>) => {
    const request = error.config as RetriableRequest | undefined;
    // 没有可用 refresh token 时保留 Gateway 的原始 401，不能伪装成“登录已失效”。
    if (!request || !shouldRefreshAfterUnauthorized(error.response?.status, request) || !tokenStorage.get()?.refreshToken) {
      return Promise.reject(error);
    }

    request._hasRetried = true;
    try {
      refreshInFlight ??= refreshTokens();
      const tokens = await refreshInFlight;
      const headers = new AxiosHeaders();
      if (request.headers) {
        Object.entries(request.headers as Record<string, unknown>).forEach(([name, value]) => {
          if (value !== undefined) headers.set(name, String(value));
        });
      }
      headers.set('Authorization', `Bearer ${tokens.accessToken}`);
      request.headers = headers;
      return apiClient(request);
    } catch (refreshError) {
      await tokenStorage.clear();
      setApiAccessToken(null);
      onSessionInvalid?.();
      // 当前请求的真实失败原因是 Gateway 的 401；刷新失败仅代表无法恢复该会话。
      return Promise.reject(error);
    } finally {
      refreshInFlight = null;
    }
  },
);

/** 保留一个独立客户端给需要绕过 Bearer 注入的普通请求测试使用。 */
export { rawClient };
