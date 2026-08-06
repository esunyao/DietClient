import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import type { ApiEnvelope, AvatarConfirmResult, AvatarPresignPayload, AvatarPresignResult, ProfileUpdatePayload, User, UserProfile } from '../../../shared/types/api';

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

  /** 用户表保存的是对象键，展示时必须换取一个短时有效的真实图片 URL。 */
  getAvatarUrl: async (): Promise<string> => {
    const response = await apiClient.get<ApiEnvelope<string>>('v1/files/avatar');
    return unwrapApiResponse(response);
  },

  createAvatarUpload: async (payload: AvatarPresignPayload): Promise<AvatarPresignResult> => {
    const response = await apiClient.post<ApiEnvelope<AvatarPresignResult>>('v1/files/avatar/presign', payload);
    return unwrapApiResponse(response);
  },

  confirmAvatarUpload: async (objectKey: string): Promise<AvatarConfirmResult> => {
    // Orion 接收 JSON 字符串，而不是 { objectKey } 对象。
    const response = await apiClient.post<ApiEnvelope<AvatarConfirmResult>>(
      'v1/files/avatar/confirm',
      JSON.stringify(objectKey),
      { headers: { 'Content-Type': 'application/json' } },
    );
    return unwrapApiResponse(response);
  },
};
