import axios, { AxiosError, AxiosHeaders, type AxiosRequestConfig, type AxiosResponse } from 'axios';

import { API_BASE_URL } from '../config/appConfig';
import type { ApiEnvelope, TokenPair } from '../types/api';
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

/** 将后端统一响应转换成调用方真正需要的 data，并保留链路信息。 */
export function unwrapApiResponse<T>(response: AxiosResponse<ApiEnvelope<T>>): T {
  const envelope = response.data;

  if (envelope.code !== 200 || envelope.data === null) {
    throw new ApiError(envelope.message || '请求未完成，请稍后重试', envelope.code, envelope.traceId);
  }

  return envelope.data;
}

/** Unit 返回 data 为 null 也是正常业务成功，用在注册、登出和修改密码等接口。 */
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
    const body = error.response?.data as ApiEnvelope<unknown> | undefined;
    return body?.message || error.message || '网络连接失败，请检查服务是否已启动';
  }

  // 本地文件校验、对象存储状态等客户端错误也需要把具体修复建议呈现给用户。
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

let refreshInFlight: Promise<TokenPair> | null = null;
let onSessionInvalid: (() => void) | null = null;

/** 独立导出方便单元测试，也让 Bearer 格式只有一个来源。 */
export function buildAuthorizationHeader(accessToken?: string): Record<string, string> {
  return accessToken ? { Authorization: `Bearer ${accessToken}` } : {};
}

export function shouldRefreshAfterUnauthorized(status?: number, request?: RetriableRequest): boolean {
  return status === 401 && Boolean(request) && !request?._hasRetried && !request?.url?.includes('v1/auth/refresh');
}

/** 会话状态在 feature 层，网络层只通过回调通知它失效，避免循环依赖。 */
export function setSessionInvalidHandler(handler: () => void): void {
  onSessionInvalid = handler;
}

async function refreshTokens(): Promise<TokenPair> {
  const tokens = tokenStorage.get();
  if (!tokens?.refreshToken) {
    throw new ApiError('登录已失效，请重新登录', 401);
  }

  const response = await rawClient.post<ApiEnvelope<TokenPair>>('v1/auth/refresh', {
    refreshToken: tokens.refreshToken,
  });
  const nextTokens = unwrapApiResponse(response);
  await tokenStorage.save(nextTokens);
  return nextTokens;
}

apiClient.interceptors.request.use(config => {
  const accessToken = tokenStorage.get()?.accessToken;
  if (accessToken) {
    // InternalAxiosRequestConfig 的 headers 已是 AxiosHeaders，可安全直接写入。
    config.headers.set('Authorization', buildAuthorizationHeader(accessToken).Authorization);
  }
  return config;
});

apiClient.interceptors.response.use(
  response => response,
  async (error: AxiosError<ApiEnvelope<unknown>>) => {
    const request = error.config as RetriableRequest | undefined;
    const isRefreshRequest = request?.url?.includes('v1/auth/refresh');

    if (!request || !shouldRefreshAfterUnauthorized(error.response?.status, request) || isRefreshRequest) {
      return Promise.reject(error);
    }

    request._hasRetried = true;

    try {
      // 多个并发请求同时过期时只刷新一次，其他请求等待相同 Promise。
      refreshInFlight ??= refreshTokens();
      const tokens = await refreshInFlight;
      // 重试会重新合并 Axios 默认请求头，因此此处只需要明确覆盖新 Token。
      const headers = new AxiosHeaders();
      headers.set('Authorization', `Bearer ${tokens.accessToken}`);
      request.headers = headers;
      return apiClient(request);
    } catch (refreshError) {
      await tokenStorage.clear();
      onSessionInvalid?.();
      return Promise.reject(refreshError);
    } finally {
      refreshInFlight = null;
    }
  },
);
