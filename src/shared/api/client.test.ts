import { assertApiSuccess, unwrapApiResponse } from './client';

describe('API success envelopes', () => {
  it('accepts a created (201) response with data', () => {
    expect(
      unwrapApiResponse({
        data: { code: 201, message: 'Created', data: { mealId: '2086475596958904300' } },
      } as never),
    ).toEqual({ mealId: '2086475596958904300' });
  });

  it('accepts every 2xx empty success response', () => {
    expect(() =>
      assertApiSuccess({ data: { code: 204, message: 'No content', data: null } } as never),
    ).not.toThrow();
  });
});
