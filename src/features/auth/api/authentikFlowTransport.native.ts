import { NativeModules, Platform } from 'react-native';

import type { NativeAuthentikFlowResponse } from './authentikFlowTransport';

type NativeAuthentikFlowModule = {
  createSession(): Promise<string>;
  request(sessionId: string, method: string, url: string, headers: Record<string, string>, body?: string): Promise<NativeAuthentikFlowResponse>;
  closeSession(sessionId: string): Promise<void>;
};

const nativeAuthentikFlow = NativeModules.AuthentikFlow as NativeAuthentikFlowModule | undefined;

export function canUseNativeAuthentikFlow(): boolean {
  return Platform.OS === 'android' && !!nativeAuthentikFlow;
}

export function createNativeAuthentikFlowSession(): Promise<string> {
  if (!nativeAuthentikFlow) {
    return Promise.reject(new Error('Authentik Flow 原生模块不可用。'));
  }
  return nativeAuthentikFlow.createSession();
}

export function requestNativeAuthentikFlow(
  sessionId: string,
  method: string,
  url: string,
  headers: Record<string, string>,
  body?: string,
): Promise<NativeAuthentikFlowResponse> {
  if (!nativeAuthentikFlow) {
    return Promise.reject(new Error('Authentik Flow 原生模块不可用。'));
  }
  return nativeAuthentikFlow.request(sessionId, method, url, headers, body);
}

export function closeNativeAuthentikFlowSession(sessionId: string): Promise<void> {
  if (!nativeAuthentikFlow) {
    return Promise.resolve();
  }
  return nativeAuthentikFlow.closeSession(sessionId);
}
