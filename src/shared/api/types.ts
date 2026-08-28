/** Orion 统一响应包装。 */
export interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T | null;
  traceId?: string | null;
  timestamp?: number | string;
}
