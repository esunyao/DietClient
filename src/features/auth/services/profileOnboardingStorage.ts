import AsyncStorage from '@react-native-async-storage/async-storage';

import type { User } from '../../../shared/types/api';

const completedKeyFor = (userId: string) => `diet-client:profile-onboarding:completed:${userId}`;
const pendingRegistrationKey = 'diet-client:profile-onboarding:pending-registration';

type PendingRegistration = {
  username: string;
  email: string;
};

function normalize(value: string | null | undefined): string {
  return value?.trim().toLocaleLowerCase() ?? '';
}

/** Stores only onboarding state; no tokens, profile content, or form drafts. */
export const profileOnboardingStorage = {
  markRegistrationPending: async (username: string, email: string): Promise<void> => {
    try {
      await AsyncStorage.setItem(pendingRegistrationKey, JSON.stringify({
        username: normalize(username),
        email: normalize(email),
      } satisfies PendingRegistration));
    } catch {
      // Registration can still continue if the non-essential local marker is unavailable.
    }
  },
  consumePendingFor: async (user: User): Promise<boolean> => {
    try {
      const raw = await AsyncStorage.getItem(pendingRegistrationKey);
      if (!raw) return false;
      const pending = JSON.parse(raw) as PendingRegistration;
      const matches = pending.username === normalize(user.username) ||
        (Boolean(user.email) && pending.email === normalize(user.email));
      if (matches) await AsyncStorage.removeItem(pendingRegistrationKey);
      return matches;
    } catch {
      return false;
    }
  },
  hasCompleted: async (userId: string): Promise<boolean> => {
    try {
      return (await AsyncStorage.getItem(completedKeyFor(userId))) === '1';
    } catch {
      return false;
    }
  },
  complete: async (userId: string): Promise<void> => {
    try {
      await AsyncStorage.setItem(completedKeyFor(userId), '1');
    } catch {
      // Onboarding must remain usable if local storage is temporarily unavailable.
    }
  },
};
