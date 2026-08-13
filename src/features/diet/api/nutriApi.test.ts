jest.mock('../../../shared/api/client', () => ({
  apiClient: { get: jest.fn(), post: jest.fn(), put: jest.fn(), delete: jest.fn() },
  unwrapApiResponse: jest.fn(response => response.data.data),
  assertApiSuccess: jest.fn(),
}));

import { apiClient } from '../../../shared/api/client';
import { nutriApi } from './nutriApi';

const getMock = apiClient.get as unknown as jest.Mock;
const postMock = apiClient.post as unknown as jest.Mock;
const putMock = apiClient.put as unknown as jest.Mock;
const deleteMock = apiClient.delete as unknown as jest.Mock;
const snowflakeId = '2086475596958904300';

describe('nutriApi contract paths', () => {
  beforeEach(() => jest.clearAllMocks());

  it('passes query filters to the meal history endpoint', async () => {
    getMock.mockResolvedValue({ data: { data: { items: [], page: {} } } });
    await nutriApi.listMeals({ dateFrom: '2026-08-01', dateTo: '2026-08-07', mealType: 'lunch', page: 2 });
    expect(getMock).toHaveBeenCalledWith('v1/nutri/meals', {
      params: { dateFrom: '2026-08-01', dateTo: '2026-08-07', mealType: 'lunch', page: 2, pageSize: 20 },
    });
  });

  it('uses an exact snowflake ID and UUID header when creating a meal', async () => {
    postMock.mockResolvedValue({ data: { data: { mealId: snowflakeId } } });
    const payload = {
      mealType: 'lunch' as const,
      consumedAt: '2026-08-13T04:00:00.000Z',
      timezone: 'Asia/Shanghai',
      entrySource: 'manual' as const,
      items: [{ foodId: snowflakeId, consumedAmountG: 150 }],
    };
    await nutriApi.createMeal(payload, '98fcaaf7-7a6e-44c2-98d0-57ddbc315346');
    expect(postMock).toHaveBeenCalledWith('v1/nutri/meals', payload, {
      headers: { 'X-Idempotency-Key': '98fcaaf7-7a6e-44c2-98d0-57ddbc315346' },
    });
  });

  it('uses exact IDs for image deletion and meal replacement', async () => {
    deleteMock.mockResolvedValue({ data: { code: 200 } });
    putMock.mockResolvedValue({ data: { data: { mealId: snowflakeId } } });
    await nutriApi.deleteMealImage(snowflakeId, '2086475596958904301');
    await nutriApi.replaceMeal(snowflakeId, {
      mealType: 'dinner', consumedAt: '2026-08-13T10:00:00.000Z', timezone: 'Asia/Shanghai', entrySource: 'manual', items: [{ foodId: snowflakeId, consumedAmountG: 120 }],
    });
    expect(deleteMock).toHaveBeenCalledWith(`v1/nutri/meals/${snowflakeId}/images/2086475596958904301`);
    expect(putMock).toHaveBeenCalledWith(`v1/nutri/meals/${snowflakeId}`, expect.any(Object));
  });
});
