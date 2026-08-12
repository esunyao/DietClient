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
});
