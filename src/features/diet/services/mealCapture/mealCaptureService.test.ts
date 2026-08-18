jest.mock('../../api/nutriApi', () => ({ nutriApi: { createCaptureSession: jest.fn(), listCaptureDrafts: jest.fn(), getCaptureSession: jest.fn(), presignCaptureImage: jest.fn(), confirmCaptureImage: jest.fn(), cancelCaptureSession: jest.fn(), submitCaptureSession: jest.fn(), retryCaptureSession: jest.fn() } }));
jest.mock('./captureSessionStorage', () => ({ readActiveCaptureSessionId: jest.fn(), saveActiveCaptureSessionId: jest.fn(), clearActiveCaptureSessionId: jest.fn() }));
jest.mock('./mealCaptureUpload', () => ({ uploadCaptureImageBinary: jest.fn() }));

import { nutriApi } from '../../api/nutriApi';
import { readActiveCaptureSessionId, saveActiveCaptureSessionId } from './captureSessionStorage';
import { createCaptureSession, listCaptureDrafts, restoreCaptureSession, submitCaptureSession, uploadAndConfirmCaptureImage } from './mealCaptureService';
import { uploadCaptureImageBinary } from './mealCaptureUpload';

const session = { captureSessionId: '2086475596958904300', status: 'created', timezone: 'Asia/Shanghai', maxImageCount: 10, expiresAt: '', analysisRequestedAt: null, images: [], createdAt: '', updatedAt: '' } as const;
describe('meal capture service', () => {
  beforeEach(() => jest.clearAllMocks());
  it('persists a created active session', async () => {
    (nutriApi.createCaptureSession as jest.Mock).mockResolvedValue(session);
    await expect(createCaptureSession('Asia/Shanghai')).resolves.toEqual(session);
    expect(saveActiveCaptureSessionId).toHaveBeenCalledWith(session.captureSessionId);
  });
  it('restores active non-terminal session', async () => {
    (readActiveCaptureSessionId as jest.Mock).mockResolvedValue(session.captureSessionId);
    (nutriApi.getCaptureSession as jest.Mock).mockResolvedValue(session);
    await expect(restoreCaptureSession()).resolves.toEqual(session);
  });
  it('reads draft list from the server', async () => {
    (nutriApi.listCaptureDrafts as jest.Mock).mockResolvedValue({ items: [], total: 0 });
    await expect(listCaptureDrafts()).resolves.toEqual({ items: [], total: 0 });
  });
  it('uses presigned imageId for ordered upload then confirmation', async () => {
    (nutriApi.presignCaptureImage as jest.Mock).mockResolvedValue({ imageId: '2086475596958904301', uploadUrl: 'https://upload', requiredHeaders: {} });
    (nutriApi.getCaptureSession as jest.Mock).mockResolvedValue(session);
    await uploadAndConfirmCaptureImage(session.captureSessionId, { uri: 'file://plate.jpg', fileName: 'plate.jpg', contentType: 'image/jpeg', byteSize: 100, capturedAt: null }, () => undefined);
    expect((uploadCaptureImageBinary as jest.Mock).mock.invocationCallOrder[0]).toBeLessThan((nutriApi.confirmCaptureImage as jest.Mock).mock.invocationCallOrder[0]);
    expect(nutriApi.confirmCaptureImage).toHaveBeenCalledWith(session.captureSessionId, '2086475596958904301');
  });
  it('submits the selected meal metadata', async () => {
    const response = { captureSession: session, meal: { mealId: '2086475596958904302', analysisStatus: 'queued' } };
    (nutriApi.submitCaptureSession as jest.Mock).mockResolvedValue(response);
    await expect(submitCaptureSession(session.captureSessionId, { mealType: 'lunch', notes: '少盐' })).resolves.toEqual(response);
    expect(nutriApi.submitCaptureSession).toHaveBeenCalledWith(session.captureSessionId, { mealType: 'lunch', notes: '少盐' });
  });
});
