import { createIdempotencyKey, parseLocalDateTime, toMealItemInputs, validateMealItems } from './mealDraft';

describe('meal draft validation', () => {
  const item = { foodId: '2086475596958904300', name: '鸡胸肉', consumedAmountG: '150', notes: '' };

  it('requires at least one distinct item with a valid weight', () => {
    expect(validateMealItems([])).toBe('请至少添加一种食物。');
    expect(validateMealItems([{ ...item, consumedAmountG: '0' }])).toContain('填写');
    expect(validateMealItems([item, { ...item, name: '重复鸡胸肉' }])).toBe('同一餐次不能重复添加同一种食物。');
  });

  it('maps a valid draft to the exact OpenAPI payload shape', () => {
    expect(toMealItemInputs([{ ...item, notes: '去皮' }])).toEqual([
      { foodId: '2086475596958904300', consumedAmountG: 150, notes: '去皮' },
    ]);
  });

  it('accepts valid local time and rejects invalid date input', () => {
    expect(parseLocalDateTime('2026-08-13 12:30')).toBeTruthy();
    expect(parseLocalDateTime('2026-02-30 12:30')).toBeNull();
  });

  it('generates an RFC 4122 v4 idempotency key', () => {
    expect(createIdempotencyKey()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });
});
