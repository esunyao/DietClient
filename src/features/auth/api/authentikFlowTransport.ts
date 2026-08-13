export type NativeAuthentikFlowResponse = {
  status: number;
  body: string;
  headers: Record<string, string | null>;
};

export function canUseNativeAuthentikFlow(): boolean {
  return false;
}

export function createNativeAuthentikFlowSession(): Promise<string> {
  return Promise.reject(new Error('当前平台不支持原生 Authentik Flow 会话。'));
}

export function requestNativeAuthentikFlow(
  _sessionId: string,
  _method: string,
  _url: string,
  _headers: Record<string, string>,
  _body?: string,
): Promise<NativeAuthentikFlowResponse> {
  return Promise.reject(new Error('当前平台不支持原生 Authentik Flow 请求。'));
}

export function closeNativeAuthentikFlowSession(_sessionId: string): Promise<void> {
  return Promise.resolve();
}
