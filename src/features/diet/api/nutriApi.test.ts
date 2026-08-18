jest.mock('../../../shared/api/client', () => ({
  apiClient: { get: jest.fn(), post: jest.fn(), put: jest.fn(), patch: jest.fn(), delete: jest.fn() },
  unwrapApiResponse: jest.fn(response => response.data.data),
  assertApiSuccess: jest.fn(),
}));

import { apiClient } from '../../../shared/api/client';
import { nutriApi } from './nutriApi';

const getMock = apiClient.get as unknown as jest.Mock;
const postMock = apiClient.post as unknown as jest.Mock;
const putMock = apiClient.put as unknown as jest.Mock;
const patchMock = apiClient.patch as unknown as jest.Mock;
const snowflakeId = '2086475596958904300';

describe('NutriMemo photo capture contract', () => {
  beforeEach(() => jest.clearAllMocks());
  it('keeps snowflake and presigned image IDs as strings', async () => {
    postMock.mockResolvedValue({ data: { data: { imageId: snowflakeId, uploadUrl: 'https://oss.example/upload', objectKey: 'private/x', requiredHeaders: {}, expiresInSeconds: 300 } } });
    const result = await nutriApi.presignCaptureImage(snowflakeId, { fileName: 'plate.jpg', contentType: 'image/jpeg', contentLength: 1024 });
    expect(result.imageId).toBe(snowflakeId);
    expect(postMock).toHaveBeenCalledWith(`v1/nutri/capture-sessions/${snowflakeId}/images/presign`, expect.objectContaining({ fileName: 'plate.jpg' }));
  });
  it('sends idempotency key when creating a session', async () => {
    postMock.mockResolvedValue({ data: { data: { captureSessionId: snowflakeId } } });
    await nutriApi.createCaptureSession({ timezone: 'Asia/Shanghai' }, '98fcaaf7-7a6e-44c2-98d0-57ddbc315346');
    expect(postMock).toHaveBeenCalledWith('v1/nutri/capture-sessions', { timezone: 'Asia/Shanghai' }, { headers: { 'X-Idempotency-Key': '98fcaaf7-7a6e-44c2-98d0-57ddbc315346' } });
  });
  it('loads server-owned draft sessions', async () => {
    getMock.mockResolvedValue({ data: { data: { items: [], total: 0 } } });
    await expect(nutriApi.listCaptureDrafts()).resolves.toEqual({ items: [], total: 0 });
    expect(getMock).toHaveBeenCalledWith('v1/nutri/capture-sessions/drafts');
  });
  it('passes keyword and pagination to history', async () => {
    getMock.mockResolvedValue({ data: { data: { items: [], page: 2, pageSize: 20, total: 0 } } });
    await nutriApi.listMeals({ dateFrom: '2026-08-01', dateTo: '2026-08-07', mealType: 'lunch', q: '鸡胸', page: 2 });
    expect(getMock).toHaveBeenCalledWith('v1/nutri/meals', { params: { dateFrom: '2026-08-01', dateTo: '2026-08-07', mealType: 'lunch', q: '鸡胸', page: 2, pageSize: 20 } });
  });
  it('confirms by imageId and replaces a whole meal without foodId', async () => {
    postMock.mockResolvedValue({ data: { data: { imageId: snowflakeId } } }); putMock.mockResolvedValue({ data: { data: { mealId: snowflakeId } } });
    await nutriApi.confirmCaptureImage('session-id', snowflakeId);
    await nutriApi.replaceMeal(snowflakeId, { mealType: 'lunch', consumedAt: '2026-08-17T04:00:00.000Z', timezone: 'Asia/Shanghai', items: [{ displayName: '鸡胸肉', estimatedWeightG: 120, nutrients: [{ nutrientCode: 'PROTEIN', amount: 31 }] }] });
    expect(postMock).toHaveBeenCalledWith(`v1/nutri/capture-sessions/session-id/images/${snowflakeId}/confirm`);
    expect(putMock).toHaveBeenCalledWith(`v1/nutri/meals/${snowflakeId}`, expect.not.objectContaining({ foodId: expect.anything() }));
  });
  it('submits meal metadata and patches metadata without replacing items', async () => {
    postMock.mockResolvedValue({ data: { data: { captureSession: { status: 'ready_for_analysis' }, meal: { mealId: snowflakeId, analysisStatus: 'queued' } } } });
    patchMock.mockResolvedValue({ data: { data: { mealId: snowflakeId } } });
    await nutriApi.submitCaptureSession('session-id', { mealType: 'dinner', notes: '少油' });
    await nutriApi.patchMeal(snowflakeId, { notes: '少盐' });
    expect(postMock).toHaveBeenCalledWith('v1/nutri/capture-sessions/session-id/submit', { mealType: 'dinner', notes: '少油' });
    expect(patchMock).toHaveBeenCalledWith(`v1/nutri/meals/${snowflakeId}`, { notes: '少盐' });
  });
});
