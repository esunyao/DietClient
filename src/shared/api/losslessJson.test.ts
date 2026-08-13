import { parseApiJson } from './losslessJson';

describe('parseApiJson', () => {
  it('keeps Orion snowflake record IDs exact while preserving ordinary numbers', () => {
    const parsed = parseApiJson('{"code":200,"data":[{"conditionId":2086475596958904300,"priority":8,"weightKg":62.3}]}') as {
      data: Array<{ conditionId: string; priority: number; weightKg: number }>;
    };

    expect(parsed.data[0]).toEqual({
      conditionId: '2086475596958904300',
      priority: 8,
      weightKg: 62.3,
    });
  });

  it('preserves already quoted IDs', () => {
    const parsed = parseApiJson('{"data":{"goalId":"2086475596958904300"}}') as { data: { goalId: string } };
    expect(parsed.data.goalId).toBe('2086475596958904300');
  });

  it('keeps NutriMemo snowflake IDs exact in nested meal responses', () => {
    const parsed = parseApiJson('{"data":{"mealId":2086475596958904300,"items":[{"itemId":2086475596958904301,"foodId":2086475596958904302}],"images":[{"imageId":2086475596958904303}]}}') as {
      data: { mealId: string; items: Array<{ itemId: string; foodId: string }>; images: Array<{ imageId: string }> };
    };

    expect(parsed.data.mealId).toBe('2086475596958904300');
    expect(parsed.data.items[0]).toEqual({ itemId: '2086475596958904301', foodId: '2086475596958904302' });
    expect(parsed.data.images[0].imageId).toBe('2086475596958904303');
  });
});
