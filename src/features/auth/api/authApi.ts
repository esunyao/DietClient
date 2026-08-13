import 'react-native-get-random-values';

import { sha256 } from '@noble/hashes/sha2.js';

import {
  canUseNativeAuthentikFlow,
  closeNativeAuthentikFlowSession,
  createNativeAuthentikFlowSession,
  requestNativeAuthentikFlow,
} from './authentikFlowTransport';

import {
  AUTHENTIK_AUTHENTICATION_FLOW_SLUG,
  AUTHENTIK_BASE_URL,
  AUTHENTIK_CLIENT_ID,
  AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG,
  AUTHENTIK_ENROLLMENT_FLOW_SLUG,
  AUTHENTIK_REDIRECT_URI,
  AUTHENTIK_SCOPES,
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

export type RegistrationResult = {
  status: 'verification_required';
  username: string;
  email: string;
};

export type RegistrationFieldName = 'username' | 'displayName' | 'email' | 'password' | 'confirmPassword';
export type RegistrationFieldErrors = Partial<Record<RegistrationFieldName, string>>;

export class AuthentikFlowError extends Error {
  constructor(
    message: string,
    public readonly component?: string,
    public readonly responseErrors?: FlowChallenge['response_errors'],
  ) {
    super(message);
    this.name = 'AuthentikFlowError';
  }
}

async function requestFlowExecutor(
  sessionId: string | null,
  url: string,
  options: RequestInit & { redirect?: 'follow' | 'error' | 'manual' },
  transport: 'fetch' | 'native',
): Promise<Response> {
  if (transport === 'fetch' || !canUseNativeAuthentikFlow()) {
    return fetch(url, options);
  }

  const nativeResponse = await requestNativeAuthentikFlow(
    sessionId as string,
    options.method || 'GET',
    url,
    options.headers as Record<string, string>,
    typeof options.body === 'string' ? options.body : undefined,
  );
  const responseHeaders = Object.fromEntries(
    Object.entries(nativeResponse.headers).filter((entry): entry is [string, string] => entry[1] !== null),
  );
  return {
    ok: nativeResponse.status >= 200 && nativeResponse.status < 300,
    status: nativeResponse.status,
    headers: new Headers(responseHeaders),
    text: async () => nativeResponse.body,
  } as Response;
}

let flowDiagnosticCounter = 0;

function debugFlow(message: string): void {
  if (typeof __DEV__ !== 'undefined' && __DEV__) {
    console.info(`[AuthentikFlow] ${message}`);
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

class FlowExecutorSession {
  /**
   * authentik flow executor 的流程会话标识。
   * GET 响应头返回 x-authentik-id，后续 POST/GET 需回传该值以维持流程状态。
   */
  private flowId = '';
  private requestCount = 0;
  private nativeSessionPromise: Promise<string> | null = null;
  private readonly diagnosticId = ++flowDiagnosticCounter;

  constructor(
    private readonly flowSlug: string,
    private readonly query: string,
    private readonly transport: 'fetch' | 'native' = 'native',
  ) {}

  private endpoint(): string {
    const base = `${AUTHENTIK_BASE_URL}${this.executorPath()}`;
    return this.query ? `${base}?query=${encodeURIComponent(this.query)}` : base;
  }

  private executorPath(): string {
    return `/api/v3/flows/executor/${this.flowSlug}/`;
  }

  private flowHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      Accept: 'application/json',
      Origin: AUTHENTIK_BASE_URL,
      Referer: `${AUTHENTIK_BASE_URL}/if/flow/${this.flowSlug}/?query=${encodeURIComponent(this.query)}`,
    };
    if (this.flowId) {
      headers['x-authentik-id'] = this.flowId;
    }
    return headers;
  }

  private async request(
    body?: Record<string, unknown>,
    requestUrl = this.endpoint(),
    executorRedirectCount = 0,
  ): Promise<FlowChallenge> {
    const headers = this.flowHeaders();
    if (body) {
      headers['Content-Type'] = 'application/json';
    }

    const requestOptions: RequestInit & { redirect?: 'follow' | 'error' | 'manual' } = {
      method: body ? 'POST' : 'GET',
      headers,
      body: body ? JSON.stringify(body) : undefined,
      // fetch 路径交给 RN NetworkingModule 的 CookieJar 保存/回传 HttpOnly Cookie；
      // native 路径则由短生命周期原生会话隔离 Cookie。
      credentials: 'include',
      // 保留 3xx 响应供上层根据 Location 判断，避免自动跟随到 HTML 页。
      redirect: 'manual',
    };
    const nativeSessionId = this.transport === 'native' ? await this.getNativeSessionId() : null;
    this.requestCount += 1;
    const method = body ? 'POST' : 'GET';
    debugFlow(
      `#${this.diagnosticId} request=${this.requestCount} method=${method} ` +
      `flow=${this.flowSlug} transport=${this.transport}`,
    );
    const response = await requestFlowExecutor(nativeSessionId, requestUrl, requestOptions, this.transport);
    // 记录首个 x-authentik-id 作为本次流程的会话标识（authentik 用它关联同一次流程的多轮请求）。
    const flowId = response.headers.get('x-authentik-id');
    if (flowId) {
      this.flowId = flowId;
    }

    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get('location') || '';
      const expectedExecutorPath = this.executorPath();
      // 不使用 Hermes 的 URL.pathname 解析 Authentik 的相对 Location。
      // 部分 Android 版本会把两个相同的 pathname 解析成不同结果。
      const isTrustedRelativeLocation = /^\/(?!\/)/.test(location);
      const isTrustedAbsoluteLocation = location.startsWith(`${AUTHENTIK_BASE_URL}/`);
      const locationWithoutOrigin = isTrustedAbsoluteLocation
        ? location.slice(AUTHENTIK_BASE_URL.length)
        : location;
      const locationPath = locationWithoutOrigin.split(/[?#]/, 1)[0];
      const isSameExecutorPath = locationPath === expectedExecutorPath;
      const isSameExecutor =
        isSameExecutorPath && (isTrustedRelativeLocation || isTrustedAbsoluteLocation);
      debugFlow(
        `#${this.diagnosticId} redirect-check relative=${isTrustedRelativeLocation} ` +
        `sameOrigin=${isTrustedAbsoluteLocation} samePath=${isSameExecutorPath}`,
      );
      // Authentik 2026.5 在一个阶段通过后使用同 Executor 的 302 推进流程。
      // 这里只跟随为 GET，绝不重发原表单 POST；响应中的新 x-authentik-id 已在
      // 上方写回，原生会话也已吸收本轮 Set-Cookie。
      if (isSameExecutor) {
        if (executorRedirectCount >= MAX_EXECUTOR_REDIRECTS) {
          throw new AuthentikFlowError('Authentik 流程跳转次数异常，请重新注册。');
        }
        const followUrl = `${AUTHENTIK_BASE_URL}${locationWithoutOrigin}`;
        debugFlow(
          `#${this.diagnosticId} response=${response.status} follow=GET ` +
          `location=${locationPath} redirect=${executorRedirectCount + 1}`,
        );
        return this.request(undefined, followUrl, executorRedirectCount + 1);
      }
      const redirect = {
        component: 'xak-flow-redirect',
        type: 'redirect',
        to: location || '/flows/-/cancel/',
      };
      let redirectPath = location || 'none';
      try {
        const parsed = new URL(location, AUTHENTIK_BASE_URL);
        redirectPath = parsed.pathname;
      } catch {
        // 仅用于开发期诊断，无法解析时保留原始相对路径。
      }
      debugFlow(`#${this.diagnosticId} response=${response.status} component=${redirect.component} location=${redirectPath}`);
      return redirect;
    }

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
    debugFlow(`#${this.diagnosticId} response=${response.status} component=${payload.component}`);
    return payload;
  }

  private getNativeSessionId(): Promise<string | null> {
    if (!canUseNativeAuthentikFlow()) return Promise.resolve(null);
    if (!this.nativeSessionPromise) {
      this.nativeSessionPromise = createNativeAuthentikFlowSession();
    }
    return this.nativeSessionPromise;
  }

  async close(): Promise<void> {
    if (!this.nativeSessionPromise) return;
    try {
      const sessionId = await this.nativeSessionPromise.catch(() => null);
      if (sessionId) await closeNativeAuthentikFlowSession(sessionId);
    } finally {
      debugFlow(`#${this.diagnosticId} closed requests=${this.requestCount}`);
      this.nativeSessionPromise = null;
    }
  }

  start(): Promise<FlowChallenge> {
    return this.request();
  }

  submit(response: Record<string, unknown>): Promise<FlowChallenge> {
    return this.request(response);
  }

  async followRedirect(to: string): Promise<string> {
    const url = new URL(to, AUTHENTIK_BASE_URL).toString();
    const headers: Record<string, string> = {
      Accept: 'application/json',
    };
    if (this.flowId) {
      headers['x-authentik-id'] = this.flowId;
    }

    const fetchOptions: RequestInit & { redirect?: 'follow' | 'error' | 'manual' } = {
      method: 'GET',
      headers,
      credentials: 'include',
      redirect: 'manual',
    };
    // 授权跳转仍需要本次 Flow 的 authentik_session，并沿用当前会话的 transport。
    const response = await requestFlowExecutor(
      this.transport === 'native' ? await this.getNativeSessionId() : null,
      url,
      fetchOptions,
      this.transport,
    );

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

const MAX_EXECUTOR_REDIRECTS = 8;

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
    scope: AUTHENTIK_SCOPES,
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
  if (/username is already taken/i.test(message)) return '用户名已被占用，请换一个用户名。';
  if (/this field is required/i.test(message)) return '请填写所有必填信息。';
  return message || '认证信息校验失败，请重试。';
}

function isEmailStageSuccess(challenge: FlowChallenge): boolean {
  if (challenge.component !== 'ak-stage-email') return false;
  if (!challenge.response_errors) return true;
  return Object.values(challenge.response_errors)
    .flat()
    .some(item => item.code === 'email-sent' || item.string === 'email-sent');
}

function registrationErrorMessage(field: string, message: string): string {
  if (/username is already taken/i.test(message)) return '用户名已被占用，请换一个用户名。';
  if (/this field is required/i.test(message)) {
    const labels: Record<string, string> = {
      username: '请输入用户名',
      nickname: '请输入昵称',
      email: '请输入邮箱',
      password: '请输入密码',
      'password-repeat': '请再次输入密码',
    };
    return labels[field] || '请填写该必填项';
  }
  return message;
}

export function getRegistrationFieldErrors(error: unknown): RegistrationFieldErrors {
  if (!(error instanceof AuthentikFlowError) || !error.responseErrors) return {};
  const fieldMap: Record<string, RegistrationFieldName> = {
    username: 'username',
    nickname: 'displayName',
    email: 'email',
    password: 'password',
    'password-repeat': 'confirmPassword',
  };
  return Object.entries(error.responseErrors).reduce<RegistrationFieldErrors>((result, [field, errors]) => {
    const formField = fieldMap[field];
    const message = errors.map(item => item.string).find(Boolean);
    if (formField && message) result[formField] = registrationErrorMessage(field, message);
    return result;
  }, {});
}

/**
 * 生成 challenge 的签名（组件 + 排序后的字段键），用于检测流程是否卡住未推进：
 * 若提交后返回与提交前相同的 challenge 且无错误，说明 flow 没有前进。
 */
function challengeSignature(challenge: FlowChallenge): string {
  const fields = Array.isArray(challenge.fields)
    ? (challenge.fields as Array<{ field_key?: string; name?: string; key?: string }>)
        .map(field => field?.field_key || field?.name || field?.key || '')
        .sort()
        .join(',')
    : '';
  return `${challenge.component}|${fields}`;
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
    else if (normalized.includes('display') || normalized === 'name' || normalized === 'nickname') response[name] = values.displayName || values.username;
  });
  return Object.keys(response).length > 1 ? response : null;
}

export function resolveRegistrationNickname(username: string, displayName?: string): string {
  return displayName?.trim() || username.trim();
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
  stopAtComponents: ReadonlySet<string> = new Set(),
): Promise<FlowChallenge> {
  let challenge = first;
  let previousSignature: string | null = null;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (challenge.component === 'xak-flow-redirect' || challenge.type === 'redirect') {
      return challenge;
    }
    if (stopAtComponents.has(challenge.component)) {
      if (isEmailStageSuccess(challenge)) return challenge;
      if (challenge.response_errors) {
        throw new AuthentikFlowError(challengeError(challenge), challenge.component, challenge.response_errors);
      }
      return challenge;
    }
    if (challenge.component === 'ak-stage-access-denied' || challenge.component === 'ak-stage-flow-error') {
      const message = String(
        challenge.error_message ||
          'Authentik 拒绝了本次请求。认证会话或 CSRF 校验未通过，请重试；若持续出现请联系管理员并提供请求编号。',
      );
      const requestId = typeof challenge.request_id === 'string' ? `（请求编号：${challenge.request_id}）` : '';
      throw new AuthentikFlowError(`${message}${requestId}`, challenge.component);
    }
    if (challenge.response_errors) {
      throw new AuthentikFlowError(challengeError(challenge), challenge.component, challenge.response_errors);
    }

    // 无进展检测：若返回与上一轮相同的 challenge（同组件、同字段）且无错误，
    // 说明 flow 卡住未推进。此时盲目重发相同数据只会得到误导性错误
    //（例如注册流程中用户已创建却弹回表单，重发即报“用户名已占用”）。
    const signature = challengeSignature(challenge);
    if (previousSignature !== null && signature === previousSignature && !challenge.response_errors) {
      throw new AuthentikFlowError(
        '认证流程未正常推进（请求可能已提交成功）。若为注册，请检查邮箱是否收到验证邮件，或稍后重试。',
        challenge.component,
      );
    }
    previousSignature = signature;

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

const registrationsInFlight = new Map<string, Promise<RegistrationResult>>();

async function performRegistration({
  username,
  email,
  password,
  displayName,
  onChallenge,
}: RegisterPayload): Promise<RegistrationResult> {
  const normalizedUsername = username.trim();
  const normalizedEmail = email.trim();
  // Android 注册使用独立原生 Flow 会话：GET 后只保存 authentik_session，POST
  // 由 AuthentikFlowSessionStore 明确写入 Cookie header，不依赖全局 CookieJar。
  // 正常协议严格为 GET -> POST -> ak-stage-email，不接受或跟随 3xx。
  const flow = new FlowExecutorSession(AUTHENTIK_ENROLLMENT_FLOW_SLUG, '', 'native');
  try {
    const first = await flow.start();
    const result = await completeFlow(flow, first, {
      username: normalizedUsername,
      email: normalizedEmail,
      password,
      displayName: resolveRegistrationNickname(normalizedUsername, displayName),
    }, onChallenge, new Set(['ak-stage-email']));
    if (result.component !== 'ak-stage-email') {
      throw new AuthentikFlowError('注册流程没有进入邮箱验证步骤。', result.component);
    }
    return { status: 'verification_required', username: normalizedUsername, email: normalizedEmail };
  } catch (error) {
    if (error instanceof AuthentikFlowError) throw error;
    throw new AuthentikFlowError('未能确认注册结果，请先检查验证邮件，不要重复提交相同账号。');
  } finally {
    await flow.close();
  }
}

function register(payload: RegisterPayload): Promise<RegistrationResult> {
  const key = `${payload.username.trim().toLocaleLowerCase()}\n${payload.email.trim().toLocaleLowerCase()}`;
  const existing = registrationsInFlight.get(key);
  if (existing) return existing;
  const request = performRegistration(payload).finally(() => {
    if (registrationsInFlight.get(key) === request) registrationsInFlight.delete(key);
  });
  registrationsInFlight.set(key, request);
  return request;
}

export const authApi = {
  login: async ({ username, password, onChallenge }: LoginPayload): Promise<OidcTokenSet> => {
    const pkce = createPkcePair();
    const authorization = createAuthorizationQuery(pkce);
    const flow = new FlowExecutorSession(AUTHENTIK_AUTHENTICATION_FLOW_SLUG, authorization.flowQuery);
    try {
      const first = await flow.start();
      const result = await completeFlow(flow, first, { username: username.trim(), password }, onChallenge);
      const flowRedirect = redirectResult(result);
      const callback = await flow.followRedirect(flowRedirect.to);
      return await exchangeAuthorizationCode(callback, pkce.verifier, authorization.state);
    } finally {
      await flow.close();
    }
  },

  register,

  resendVerificationEmail: async (email: string): Promise<void> => {
    const flow = new FlowExecutorSession(AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG, '', 'native');
    try {
      const first = await flow.start();
      const result = await completeFlow(
        flow,
        first,
        { email: email.trim() },
        undefined,
        new Set(['ak-stage-email']),
      );
      if (result.component === 'ak-stage-email') return;
      throw new AuthentikFlowError('重发验证邮件流程没有正常结束。', result.component);
    } finally {
      await flow.close();
    }
  },

  refresh: refreshAccessToken,
};
