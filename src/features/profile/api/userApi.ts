import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type { ApiEnvelope, ProfileUpdatePayload, User, UserProfile } from '../../../shared/types/api';

export const userApi = {
  getSelf: async (): Promise<User> => {
    const response = await apiClient.get<ApiEnvelope<User>>('v1/users/self');
    return unwrapApiResponse(response);
  },

  getProfile: async (): Promise<UserProfile> => {
    const response = await apiClient.get<ApiEnvelope<UserProfile>>('v1/users/self/profile');
    return unwrapApiResponse(response);
  },

  updateSelf: async (nickname: string): Promise<User> => {
    const response = await apiClient.put<ApiEnvelope<User>>('v1/users/self', { nickname });
    return unwrapApiResponse(response);
  },

  updateProfile: async (payload: ProfileUpdatePayload): Promise<UserProfile> => {
    const response = await apiClient.put<ApiEnvelope<UserProfile>>('v1/users/self/profile', payload);
    return unwrapApiResponse(response);
  },

  changePassword: async (oldPassword: string, newPassword: string): Promise<void> => {
    const response = await apiClient.put<ApiEnvelope<unknown>>('v1/users/self/password', {
      oldPassword,
      newPassword,
    });
    assertApiSuccess(response);
  },
};
