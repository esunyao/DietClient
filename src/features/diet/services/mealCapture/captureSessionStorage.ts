import AsyncStorage from '@react-native-async-storage/async-storage';

import type { CaptureSessionId } from '../../api/nutriTypes';

const STORAGE_KEY = 'diet.capture.last-draft.v1';
const LEGACY_STORAGE_KEY = 'diet.capture.active-session.v1';

export async function readLastDraftId(): Promise<CaptureSessionId | null> {
  const current = await AsyncStorage.getItem(STORAGE_KEY);
  if (current) return current;
  return AsyncStorage.getItem(LEGACY_STORAGE_KEY);
}

export async function saveLastDraftId(sessionId: CaptureSessionId): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, sessionId);
  await AsyncStorage.removeItem(LEGACY_STORAGE_KEY);
}

export async function clearLastDraftId(): Promise<void> {
  await AsyncStorage.removeItem(STORAGE_KEY);
  await AsyncStorage.removeItem(LEGACY_STORAGE_KEY);
}

// 兼容旧版本调用方，读取时会自动迁移旧键。
export const readActiveCaptureSessionId = readLastDraftId;
export const saveActiveCaptureSessionId = saveLastDraftId;
export const clearActiveCaptureSessionId = clearLastDraftId;
