import { nutriApi } from '../../api/nutriApi';
import type {
  CaptureDraftPage,
  CaptureSession,
  CaptureSessionId,
  CaptureSubmitRequest,
  CaptureSubmission,
} from '../../api/nutriTypes';
import {
  clearActiveCaptureSessionId,
  readActiveCaptureSessionId,
  saveActiveCaptureSessionId,
} from './captureSessionStorage';
import { createIdempotencyKey } from './captureUtils';
import { uploadCaptureImageBinary } from './mealCaptureUpload';
import type { CaptureImageFile, CaptureUploadProgress } from './mealCapture.types';

const terminalStatuses = new Set(['completed', 'expired', 'cancelled']);

export async function createCaptureSession(timezone: string): Promise<CaptureSession> {
  const session = await nutriApi.createCaptureSession({ timezone }, createIdempotencyKey());
  await saveActiveCaptureSessionId(session.captureSessionId);
  return session;
}

export async function listCaptureDrafts(): Promise<CaptureDraftPage> {
  return nutriApi.listCaptureDrafts();
}

export async function restoreCaptureSession(
  drafts?: CaptureDraftPage,
): Promise<CaptureSession | null> {
  const sessionId = await readActiveCaptureSessionId();
  const available =
    drafts ?? (nutriApi.listCaptureDrafts ? await nutriApi.listCaptureDrafts() : undefined);
  const selectedId =
    sessionId && available?.items.some(item => item.captureSessionId === sessionId)
      ? sessionId
      : available?.items[0]?.captureSessionId ?? sessionId;
  if (!selectedId) return null;
  try {
    const session = await nutriApi.getCaptureSession(selectedId);
    if (terminalStatuses.has(session.status)) await clearActiveCaptureSessionId();
    return terminalStatuses.has(session.status) ? null : session;
  } catch {
    await clearActiveCaptureSessionId();
    return null;
  }
}

/** 一次只处理一张图，调用方按选择顺序串行执行，避免并发抢占服务端槽位。 */
export async function uploadAndConfirmCaptureImage(
  sessionId: CaptureSessionId,
  file: CaptureImageFile,
  onProgress: CaptureUploadProgress,
): Promise<CaptureSession> {
  if (!Number.isFinite(file.byteSize) || file.byteSize <= 0)
    throw new Error('无法读取图片大小，请重新选择。');
  const presign = await nutriApi.presignCaptureImage(sessionId, {
    fileName: file.fileName,
    contentType: file.contentType,
    contentLength: file.byteSize,
    capturedAt: file.capturedAt,
  });
  await uploadCaptureImageBinary(file, presign.uploadUrl, presign.requiredHeaders, onProgress);
  await nutriApi.confirmCaptureImage(sessionId, presign.imageId);
  return nutriApi.getCaptureSession(sessionId);
}

export async function endCaptureSession(sessionId: CaptureSessionId): Promise<void> {
  await nutriApi.cancelCaptureSession(sessionId);
  await clearActiveCaptureSessionId();
}

export async function submitCaptureSession(
  sessionId: CaptureSessionId,
  payload: CaptureSubmitRequest,
): Promise<CaptureSubmission> {
  return nutriApi.submitCaptureSession(sessionId, payload);
}

export async function retryCaptureSession(sessionId: CaptureSessionId): Promise<CaptureSubmission> {
  return nutriApi.retryCaptureSession(sessionId);
}
