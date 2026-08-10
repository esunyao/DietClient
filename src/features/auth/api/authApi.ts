import 'react-native-get-random-values';

import { sha256 } from '@noble/hashes/sha2.js';

import {
  AUTHENTIK_AUTHENTICATION_FLOW_SLUG,
  AUTHENTIK_BASE_URL,
  AUTHENTIK_CLIENT_ID,
  AUTHENTIK_ENROLLMENT_FLOW_SLUG,
  AUTHENTIK_REDIRECT_URI,
} from '../../../shared/config/appConfig';
import { tokenStorage } from '../../../shared/api/tokenStorage';
import type { OidcTokenSet } from '../../../shared/types/api';

export interface FlowChallenge {
  component: string;
  type?: string;
  to?: string;
  request_id?: string;
  error_message?: string;
  response_errors?: Record<string, Array<{ string?: string; code?: string }>>;
  [key: string]: unknown;
}

export type FlowChallengeResponder = (
  challenge: FlowChallenge,
) => Promise<Record<string, unknown>>;

export interface LoginPayload {
  username: string;
  password: string;
  onChallenge?: FlowChallengeResponder;
}

export interface RegisterPayload {
  username: string;
  email: string;
  password: string;
  displayName?: string;
  onChallenge?: FlowChallengeResponder;
}

export class AuthentikFlowError extends Error {
  constructor(message: string, public readonly component?: string) {
    super(message);
    this.name = 'AuthentikFlowError';
  }
}

function base64UrlEncode(bytes: Uint8Array): string {
  /* eslint-disable no-bitwise */
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let output = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const a = bytes[index];
    const b = bytes[index + 1] ?? 0;
    const c = bytes[index + 2] ?? 0;
    const value = (a << 16) | (b << 8) | c;
    output += alphabet[(value >> 18) & 63];
    output += alphabet[(value >> 12) & 63];
    output += index + 1 < bytes.length ? alphabet[(value >> 6) & 63] : '=';
    output += index + 2 < bytes.length ? alphabet[value & 63] : '=';
  }
  /* eslint-enable no-bitwise */
  return output.replace(/\+/g, '-').replace(new RegExp('/', 'g'), '_').replace(new RegExp('=+$', 'g'), '');
}

function randomUrlValue(byteLength = 32): string {
  const bytes = new Uint8Array(byteLength);
  const cryptoApi = (globalThis as unknown as { crypto?: { getRandomValues: (value: Uint8Array) => Uint8Array } }).crypto;
  if (!cryptoApi?.getRandomValues) {
    throw new AuthentikFlowError('当前设备不支持安全随机数，无法启动登录。');
  }
  cryptoApi.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

export function createPkcePair(): { verifier: string; challenge: string } {
  const verifier = randomUrlValue(32);
  const challenge = base64UrlEncode(sha256(new Uint8Array(Array.from(verifier, char => char.charCodeAt(0)))));
  return { verifier, challenge };
}

class MemoryCookieJar {
  private readonly values = new Map<string, string>();

  absorb(headers: Headers): void {
    const raw = headers.get('set-cookie');
    if (!raw) {
      return;
    }

    raw.split(/,(?=[^;,]+=)/).forEach(cookie => {
      const pair = cookie.split(';', 1)[0]?.trim();
      const separator = pair?.indexOf('=') ?? -1;
      if (!pair || separator <= 0) {
        return;
      }
      this.values.set(pair.slice(0, separator), pair.slice(separator + 1));
    });
  }

  header(): string | undefined {
    if (!this.values.size) {
      return undefined;
    }
    return Array.from(this.values.entries())
      .map(([name, value]) => `${name}=${value}`)
      .join('; ');
  }
}

class FlowExecutorSession {
  private readonly cookies = new MemoryCookieJar();

  constructor(
    private readonly flowSlug: string,
    private readonly query: string,
  ) {}

  private endpoint(): string {
    return `${AUTHENTIK_BASE_URL}/api/v3/flows/executor/${this.flowSlug}/?query=${encodeURIComponent(this.query)}`;
  }

  private async request(body?: Record<string, unknown>): Promise<FlowChallenge> {
    const headers: Record<string, string> = { Accept: 'application/json' };
    const cookie = this.cookies.header();
    if (cookie) {
      headers.Cookie = cookie;
    }
    if (body) {
      headers['Content-Type'] = 'application/json';
    }

    const response = await fetch(this.endpoint(), {
      method: body ? 'POST' : 'GET',
      headers,
      body: body ? JSON.stringify(body) : undefined,
      // authentik 的流程状态只使用本次登录的内存 Cookie，避免 Android 原生 Cookie 池
      // 遗留会话与手工 Cookie 同时发送，导致服务端流程状态不一致。
      credentials: 'omit',
    });
    this.cookies.absorb(response.headers);

    const text = await response.text();
    let payload: FlowChallenge | { error?: string; detail?: string } = {};
    if (text) {
      try {
        payload = JSON.parse(text) as FlowChallenge;
      } catch {
        throw new AuthentikFlowError('Authentik 返回了无法识别的流程响应。');
      }
    }

    if (!response.ok) {
      const errorPayload = payload as { error?: string; detail?: string };
      throw new AuthentikFlowError(
        errorPayload.detail || errorPayload.error || `Authentik 流程请求失败（HTTP ${response.status}）。`,
      );
    }

    if (!('component' in payload) || typeof payload.component !== 'string') {
      throw new AuthentikFlowError('Authentik 未返回有效的流程组件。');
    }
    return payload;
  }

  start(): Promise<FlowChallenge> {
    return this.request();
  }

  submit(response: Record<string, unknown>): Promise<FlowChallenge> {
    return this.request(response);
  }

  async followRedirect(to: string): Promise<string> {
    const url = new URL(to, AUTHENTIK_BASE_URL).toString();
    const headers: Record<string, string> = { Accept: 'application/json' };
    const cookie = this.cookies.header();
    if (cookie) {
      headers.Cookie = cookie;
    }

    const fetchOptions: RequestInit & { redirect?: 'follow' | 'error' | 'manual' } = {
      method: 'GET',
      headers,
      credentials: 'omit',
      redirect: 'manual',
    };
    const response = await fetch(url, fetchOptions);
    this.cookies.absorb(response.headers);

    const location = response.headers.get('location');
    if (location) {
      // 自定义协议（diethealth://）在部分 Hermes 版本的 URL 解析行为不一致，
      // 绝对地址直接透传，避免改变其中的 code/state 查询参数。
      if (/^[a-z][a-z0-9+.-]*:/i.test(location)) {
        return location;
      }
      return new URL(location, url).toString();
    }

    const text = await response.text();
    if (!response.ok) {
      throw new AuthentikFlowError(`Authentik 授权请求失败（HTTP ${response.status}）。`);
    }
    throw new AuthentikFlowError(text ? 'Authentik 没有返回授权回调地址。' : 'Authentik 授权请求没有返回回调地址。');
  }
}

function createAuthorizationQuery(pkce: { challenge: string }): {
  query: string;
  flowQuery: string;
  state: string;
  nonce: string;
} {
  const state = randomUrlValue(24);
  const nonce = randomUrlValue(24);
  const query = new URLSearchParams({
    client_id: AUTHENTIK_CLIENT_ID,
    redirect_uri: AUTHENTIK_REDIRECT_URI,
    response_type: 'code',
    scope: 'openid email profile',
    state,
    nonce,
    code_challenge: pkce.challenge,
    code_challenge_method: 'S256',
  }).toString();
  const authorizationPath = `/application/o/authorize/?${query}`;
  const flowQuery = `${query}&next=${encodeURIComponent(authorizationPath)}`;
  return { query, flowQuery, state, nonce };
}

function redirectResult(challenge: FlowChallenge): { to: string } {
  if (challenge.component !== 'xak-flow-redirect' && challenge.type !== 'redirect') {
    throw new AuthentikFlowError('认证流程尚未完成。', challenge.component);
  }
  const to = typeof challenge.to === 'string' ? challenge.to : '';
  if (!to) {
    throw new AuthentikFlowError('Authentik 完成了流程，但没有返回授权地址。', challenge.component);
  }
  return { to };
}

function challengeError(challenge: FlowChallenge): string {
  const errors = challenge.response_errors;
  if (!errors) {
    return '请完成当前认证步骤。';
  }
  const message = Object.values(errors)
    .flat()
    .map(item => item.string)
    .filter(Boolean)
    .join('；');
  return message || '认证信息校验失败，请重试。';
}

function promptResponse(
  challenge: FlowChallenge,
  values: { username?: string; email?: string; password?: string; displayName?: string },
): Record<string, unknown> | null {
  const fields = Array.isArray(challenge.fields) ? challenge.fields : [];
  const response: Record<string, unknown> = { component: challenge.component };
  fields.forEach(field => {
    if (!field || typeof field !== 'object') {
      return;
    }
    const item = field as { name?: string; field_key?: string; key?: string };
    const name = item.name || item.field_key || item.key;
    if (!name) {
      return;
    }
    const normalized = name.toLowerCase();
    if (normalized.includes('email')) response[name] = values.email;
    else if (normalized.includes('user') || normalized === 'uid') response[name] = values.username;
    else if (normalized.includes('pass')) response[name] = values.password;
    else if (normalized.includes('display') || normalized === 'name') response[name] = values.displayName;
  });
  return Object.keys(response).length > 1 ? response : null;
}

async function exchangeAuthorizationCode(to: string, verifier: string, expectedState: string): Promise<OidcTokenSet> {
  const queryStart = to.indexOf('?');
  const fragmentStart = to.indexOf('#', queryStart + 1);
  const rawQuery = queryStart >= 0
    ? to.slice(queryStart + 1, fragmentStart >= 0 ? fragmentStart : undefined)
    : '';
  const callback = new URLSearchParams(rawQuery);
  const code = callback.get('code');
  const state = callback.get('state');
  const error = callback.get('error_description') || callback.get('error');
  if (error) {
    throw new AuthentikFlowError(error);
  }
  if (!code || state !== expectedState) {
    throw new AuthentikFlowError('授权响应校验失败，请重新登录。');
  }

  const response = await fetch(`${AUTHENTIK_BASE_URL}/application/o/token/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: AUTHENTIK_CLIENT_ID,
      redirect_uri: AUTHENTIK_REDIRECT_URI,
      code,
      code_verifier: verifier,
    }).toString(),
  });
  const payload = (await response.json()) as {
    access_token?: string;
    refresh_token?: string;
    token_type?: string;
    expires_in?: number;
    id_token?: string;
    error_description?: string;
  };
  if (!response.ok || !payload.access_token) {
    throw new AuthentikFlowError(payload.error_description || `Token 交换失败（HTTP ${response.status}）。`);
  }
  return {
    accessToken: payload.access_token,
    refreshToken: payload.refresh_token || null,
    tokenType: payload.token_type || 'Bearer',
    expiresIn: payload.expires_in || 300,
    idToken: payload.id_token,
    obtainedAt: Date.now(),
  };
}

async function completeFlow(
  flow: FlowExecutorSession,
  first: FlowChallenge,
  values: { username?: string; email?: string; password?: string; displayName?: string },
  onChallenge?: FlowChallengeResponder,
): Promise<FlowChallenge> {
  let challenge = first;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (challenge.component === 'xak-flow-redirect' || challenge.type === 'redirect') {
      return challenge;
    }
    if (challenge.component === 'ak-stage-access-denied' || challenge.component === 'ak-stage-flow-error') {
      const message = String(challenge.error_message || 'Authentik 拒绝了本次请求。');
      const requestId = typeof challenge.request_id === 'string' ? `（请求编号：${challenge.request_id}）` : '';
      throw new AuthentikFlowError(`${message}${requestId}`, challenge.component);
    }

    let response: Record<string, unknown> | null = null;
    switch (challenge.component) {
      case 'ak-stage-identification':
        response = { component: challenge.component, uid_field: (values.username || values.email || '').trim() };
        break;
      case 'ak-stage-password':
        response = { component: challenge.component, password: values.password };
        break;
      case 'ak-stage-user-login':
      case 'ak-stage-autosubmit':
      case 'ak-stage-email':
        response = { component: challenge.component };
        break;
      default:
        response = promptResponse(challenge, values);
        if (!response && onChallenge) {
          response = await onChallenge(challenge);
          response = { component: challenge.component, ...response };
        }
        break;
    }

    if (!response) {
      throw new AuthentikFlowError(`客户端暂不支持认证组件：${challenge.component}。请更新客户端。`, challenge.component);
    }
    challenge = await flow.submit(response);
    if (challenge.response_errors) {
      throw new AuthentikFlowError(challengeError(challenge), challenge.component);
    }
  }
  throw new AuthentikFlowError('认证流程步骤过多，已停止本次请求。');
}

export async function refreshAccessToken(): Promise<OidcTokenSet> {
  const current = tokenStorage.get();
  if (!current?.refreshToken) {
    throw new AuthentikFlowError('登录已失效，请重新登录。');
  }
  const response = await fetch(`${AUTHENTIK_BASE_URL}/application/o/token/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: AUTHENTIK_CLIENT_ID,
      refresh_token: current.refreshToken,
    }).toString(),
  });
  const payload = (await response.json()) as {
    access_token?: string;
    refresh_token?: string;
    token_type?: string;
    expires_in?: number;
    id_token?: string;
    error_description?: string;
  };
  if (!response.ok || !payload.access_token) {
    throw new AuthentikFlowError(payload.error_description || '登录已失效，请重新登录。');
  }
  return {
    accessToken: payload.access_token,
    refreshToken: payload.refresh_token || current.refreshToken,
    tokenType: payload.token_type || current.tokenType,
    expiresIn: payload.expires_in || 300,
    idToken: payload.id_token,
    obtainedAt: Date.now(),
  };
}

export const authApi = {
  login: async ({ username, password, onChallenge }: LoginPayload): Promise<OidcTokenSet> => {
    const pkce = createPkcePair();
    const authorization = createAuthorizationQuery(pkce);
    const flow = new FlowExecutorSession(AUTHENTIK_AUTHENTICATION_FLOW_SLUG, authorization.flowQuery);
    const first = await flow.start();
    const result = await completeFlow(flow, first, { username: username.trim(), password }, onChallenge);
    const flowRedirect = redirectResult(result);
    const callback = await flow.followRedirect(flowRedirect.to);
    return exchangeAuthorizationCode(callback, pkce.verifier, authorization.state);
  },

  register: async ({ username, email, password, displayName, onChallenge }: RegisterPayload): Promise<void> => {
    const flow = new FlowExecutorSession(AUTHENTIK_ENROLLMENT_FLOW_SLUG, '');
    const first = await flow.start();
    const result = await completeFlow(flow, first, {
      username: username.trim(),
      email: email.trim(),
      password,
      displayName: displayName?.trim(),
    }, onChallenge);
    if (result.component === 'ak-stage-access-denied' || result.component === 'ak-stage-flow-error') {
      throw new AuthentikFlowError(String(result.error_message || '注册失败。'), result.component);
    }
    if (result.component === 'xak-flow-redirect' || result.type === 'redirect') {
      return;
    }
    throw new AuthentikFlowError('注册流程没有正常结束。');
  },

  refresh: refreshAccessToken,
};
