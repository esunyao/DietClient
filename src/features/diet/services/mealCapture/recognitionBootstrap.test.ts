import { loadRecognitionBootstrap, RECENT_MEAL_WINDOW_DAYS, recentMealQuery } from './recognitionBootstrap';
import type { CapturePolicy } from '../../api/nutriTypes';

const policy: CapturePolicy = { maxImageCount: 10, maxFileSizeBytes: 10 * 1024 * 1024, allowedContentTypes: ['image/jpeg'], sessionExpiresInSeconds: 86_400, maxDraftSessionCount: 5, draftExpiresInSeconds: 86_400 };

describe('recognition bootstrap', () => {
  it('queries at most the recent thirty-day window', () => {
    expect(recentMealQuery(new Date(2026, 7, 18))).toEqual({ dateFrom: '2026-07-19', dateTo: '2026-08-18', pageSize: 6 });
    expect(RECENT_MEAL_WINDOW_DAYS).toBe(30);
  });

  it('preserves an available capture policy when history fails', async () => {
    const result = await loadRecognitionBootstrap({
      policy: async () => policy,
      drafts: async () => ({ items: [], total: 0 }),
      history: async () => Promise.reject(new Error('history unavailable')),
    });
    expect(result.policy).toEqual({ status: 'fulfilled', value: policy });
    expect(result.drafts).toEqual({ status: 'fulfilled', value: { items: [], total: 0 } });
    expect(result.history.status).toBe('rejected');
  });

  it('keeps history independent when policy fails', async () => {
    const result = await loadRecognitionBootstrap({
      policy: async () => Promise.reject(new Error('policy unavailable')),
      drafts: async () => ({ items: [], total: 0 }),
      history: async () => ({ items: [] }),
    });
    expect(result.policy.status).toBe('rejected');
    expect(result.history).toEqual({ status: 'fulfilled', value: { items: [] } });
  });
});
