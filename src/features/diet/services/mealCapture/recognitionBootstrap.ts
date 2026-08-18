import type { CaptureDraftPage, CapturePolicy, MealHistoryItem } from '../../api/nutriTypes';
import { nutriApi, type MealListQuery } from '../../api/nutriApi';
import { localDateFromDate } from './captureUtils';

export const RECENT_MEAL_WINDOW_DAYS = 30;

export function recentMealQuery(now = new Date()): MealListQuery {
  const from = new Date(now);
  from.setDate(from.getDate() - RECENT_MEAL_WINDOW_DAYS);
  return { dateFrom: localDateFromDate(from), dateTo: localDateFromDate(now), pageSize: 6 };
}

export type RecognitionBootstrap = {
  policy: PromiseSettledResult<CapturePolicy>;
  drafts: PromiseSettledResult<CaptureDraftPage>;
  history: PromiseSettledResult<{ items: MealHistoryItem[] }>;
};

export type RecognitionBootstrapLoaders = {
  policy: () => Promise<CapturePolicy>;
  drafts: () => Promise<CaptureDraftPage>;
  history: () => Promise<{ items: MealHistoryItem[] }>;
};

/** 三项首屏数据互不依赖；任一失败不得遮蔽其余成功结果。 */
export async function loadRecognitionBootstrap(loaders: RecognitionBootstrapLoaders = {
  policy: nutriApi.getCapturePolicy,
  drafts: nutriApi.listCaptureDrafts,
  history: () => nutriApi.listMeals(recentMealQuery()),
}): Promise<RecognitionBootstrap> {
  const [policy, drafts, history] = await Promise.allSettled([
    loaders.policy(),
    loaders.drafts(),
    loaders.history(),
  ]);
  return { policy, drafts, history };
}
