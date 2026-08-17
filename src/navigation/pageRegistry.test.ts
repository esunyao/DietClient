import { isBottomTabVisibleForDietRoute, pageRegistry } from './pageRegistry';

describe('diet page registry', () => {
  it('keeps Recognition as the bottom tab root only', () => {
    expect(isBottomTabVisibleForDietRoute('Recognition')).toBe(true);
    expect(isBottomTabVisibleForDietRoute('MealDetail')).toBe(false);
    expect(pageRegistry.recognition.root).toBe(true);
  });
  it('uses a unified back chrome for detail and correction', () => {
    expect(pageRegistry.mealDetail.showBack).toBe(true);
    expect(pageRegistry.mealCorrection.showBottomTab).toBe(false);
  });
});
