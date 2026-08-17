import type { CapturePolicy, CaptureSession, MealHistoryItem } from '../../api/nutriTypes';
import { nutriApi, type MealListQuery } from '../../api/nutriApi';
import { localDateFromDate } from './captureUtils';
import { restoreCaptureSession } from './mealCaptureService';

export const RECENT_MEAL_WINDOW_DAYS = 30;

export function recentMealQuery(now = new Date()): MealListQuery {
  const from = new Date(now);
  from.setDate(from.getDate() - RECENT_MEAL_WINDOW_DAYS);
  return { dateFrom: localDateFromDate(from), dateTo: localDateFromDate(now), pageSize: 6 };
}

export type RecognitionBootstrap = {
  policy: PromiseSettledResult<CapturePolicy>;
  session: PromiseSettledResult<CaptureSession | null>;
  history: PromiseSettledResult<{ items: MealHistoryItem[] }>;
};

export type RecognitionBootstrapLoaders = {
  policy: () => Promise<CapturePolicy>;
  session: () => Promise<CaptureSession | null>;
  history: () => Promise<{ items: MealHistoryItem[] }>;
};

/** 三项首屏数据互不依赖；任一失败不得遮蔽其余成功结果。 */
export async function loadRecognitionBootstrap(loaders: RecognitionBootstrapLoaders = {
  policy: nutriApi.getCapturePolicy,
  session: restoreCaptureSession,
  history: () => nutriApi.listMeals(recentMealQuery()),
}): Promise<RecognitionBootstrap> {
  const [policy, session, history] = await Promise.allSettled([
    loaders.policy(),
    loaders.session(),
    loaders.history(),
  ]);
  return { policy, session, history };
}
