jest.mock('../api/nutriApi', () => ({
  nutriApi: { presignMealImage: jest.fn(), confirmMealImage: jest.fn() },
}));
jest.mock('./mealImageUpload', () => ({ uploadMealImageBinary: jest.fn() }));

import { nutriApi } from '../api/nutriApi';
import { uploadMealImageBinary } from './mealImageUpload';
import { uploadConfirmedMealImage } from './mealImageService';

const presignMock = nutriApi.presignMealImage as jest.Mock;
const confirmMock = nutriApi.confirmMealImage as jest.Mock;
const binaryMock = uploadMealImageBinary as jest.Mock;

describe('meal image upload chain', () => {
  beforeEach(() => jest.clearAllMocks());

  it('performs presign, binary PUT, then confirmation in order', async () => {
    presignMock.mockResolvedValue({ uploadUrl: 'https://oss.example/upload', objectKey: 'nutri/user/meal/image.jpg', requiredHeaders: { 'Content-Type': 'image/jpeg' } });
    binaryMock.mockResolvedValue(undefined);
    confirmMock.mockResolvedValue({ imageId: '2086475596958904301' });
    const onProgress = jest.fn();
    const file = { uri: '/cache/meal.jpg', fileName: 'meal.jpg', contentType: 'image/jpeg' as const, byteSize: 1024, capturedAt: '2026-08-13T04:00:00.000Z' };

    await uploadConfirmedMealImage('2086475596958904300', file, onProgress);

    expect(presignMock).toHaveBeenCalledWith('2086475596958904300', { fileName: 'meal.jpg', contentType: 'image/jpeg', contentLength: 1024, capturedAt: '2026-08-13T04:00:00.000Z' });
    expect(binaryMock).toHaveBeenCalledWith(file, 'https://oss.example/upload', { 'Content-Type': 'image/jpeg' }, onProgress);
    expect(confirmMock).toHaveBeenCalledWith('2086475596958904300', 'nutri/user/meal/image.jpg', '2026-08-13T04:00:00.000Z');
  });

  it('does not request a presigned URL for an unreadable file', async () => {
    await expect(uploadConfirmedMealImage('2086475596958904300', { uri: '/cache/empty.jpg', fileName: 'empty.jpg', contentType: 'image/jpeg', byteSize: 0, capturedAt: null }, jest.fn())).rejects.toThrow('无法确认图片大小');
    expect(presignMock).not.toHaveBeenCalled();
  });
});
