import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type { ApiEnvelope, LoginPayload, RegisterPayload, TokenPair } from '../../../shared/types/api';

export const authApi = {
  login: async (payload: LoginPayload): Promise<TokenPair> => {
    const response = await apiClient.post<ApiEnvelope<TokenPair>>('v1/auth/login', payload);
    return unwrapApiResponse(response);
  },

  register: async (payload: RegisterPayload): Promise<void> => {
    const response = await apiClient.post<ApiEnvelope<unknown>>('v1/auth/register', payload);
    assertApiSuccess(response);
  },

  logout: async (refreshToken: string): Promise<void> => {
    const response = await apiClient.post<ApiEnvelope<unknown>>('v1/auth/logout', { refreshToken });
    assertApiSuccess(response);
  },
};
