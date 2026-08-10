import { apiClient, unwrapApiResponse } from '../../../shared/api/client';
import type {
  ApiEnvelope,
  AvatarConfirmResult,
  AvatarPresignPayload,
  AvatarPresignResult,
  UserProfileUpdatePayload,
  User,
  UserProfile,
} from '../../../shared/types/api';

export const userApi = {
  getSelf: async (): Promise<User> => {
    const response = await apiClient.get<ApiEnvelope<User>>('v1/users/self');
    return unwrapApiResponse(response);
  },

  deactivateSelf: async (): Promise<void> => {
    await apiClient.delete<ApiEnvelope<null>>('v1/users/self');
  },

  getProfile: async (): Promise<UserProfile> => {
    const response = await apiClient.get<ApiEnvelope<UserProfile>>('v1/users/self/profile');
    return unwrapApiResponse(response);
  },

  updateProfile: async (payload: UserProfileUpdatePayload): Promise<UserProfile> => {
    const response = await apiClient.patch<ApiEnvelope<UserProfile>>('v1/users/self/profile', payload);
    return unwrapApiResponse(response);
  },

  getAvatarUrl: async (): Promise<string> => {
    const response = await apiClient.get<ApiEnvelope<string>>('v1/files/avatar');
    return unwrapApiResponse(response);
  },

  createAvatarUpload: async (payload: AvatarPresignPayload): Promise<AvatarPresignResult> => {
    const response = await apiClient.post<ApiEnvelope<AvatarPresignResult>>('v1/files/avatar/presign', payload);
    return unwrapApiResponse(response);
  },

  confirmAvatarUpload: async (objectKey: string): Promise<AvatarConfirmResult> => {
    const response = await apiClient.post<ApiEnvelope<AvatarConfirmResult>>(
      'v1/files/avatar/confirm',
      JSON.stringify(objectKey),
      { headers: { 'Content-Type': 'application/json' } },
    );
    return unwrapApiResponse(response);
  },
};
