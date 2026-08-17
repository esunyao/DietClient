import AsyncStorage from '@react-native-async-storage/async-storage';

import type { CaptureSessionId } from '../../api/nutriTypes';

const STORAGE_KEY = 'diet.capture.active-session.v1';

export async function readActiveCaptureSessionId(): Promise<CaptureSessionId | null> {
  return AsyncStorage.getItem(STORAGE_KEY);
}

export async function saveActiveCaptureSessionId(sessionId: CaptureSessionId): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, sessionId);
}

export async function clearActiveCaptureSessionId(): Promise<void> {
  await AsyncStorage.removeItem(STORAGE_KEY);
}
