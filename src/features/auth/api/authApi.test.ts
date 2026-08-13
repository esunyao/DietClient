import {
  AuthentikFlowError,
  authApi,
  createPkcePair,
  getRegistrationFieldErrors,
  resolveRegistrationNickname,
} from './authApi';

function jsonResponse(payload: unknown, headers?: Record<string, string>, status = 200): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(headers),
    text: async () => JSON.stringify(payload),
    json: async () => payload,
  } as Response;
}

describe('createPkcePair', () => {
  it('creates a URL-safe verifier and S256 challenge', () => {
    const first = createPkcePair();
    const second = createPkcePair();

    expect(first.verifier).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(first.challenge).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(first.verifier.length).toBeGreaterThanOrEqual(43);
    expect(first.challenge.length).toBeGreaterThanOrEqual(40);
    expect(first.verifier).not.toBe(second.verifier);
  });
});

describe('resolveRegistrationNickname', () => {
  it('uses the username when the optional display name is empty', () => {
    expect(resolveRegistrationNickname('new-user', '   ')).toBe('new-user');
    expect(resolveRegistrationNickname('new-user')).toBe('new-user');
  });

  it('keeps a non-empty display name', () => {
    expect(resolveRegistrationNickname('new-user', '小新')).toBe('小新');
  });
});

describe('getRegistrationFieldErrors', () => {
  it('maps Authentik prompt errors to registration fields', () => {
    const error = new AuthentikFlowError('校验失败', 'ak-stage-prompt', {
      username: [{ string: 'Username is already taken.', code: 'invalid' }],
      email: [{ string: 'Enter a valid email address.', code: 'invalid' }],
      'password-repeat': [{ string: 'This field is required.', code: 'required' }],
    });

    expect(getRegistrationFieldErrors(error)).toEqual({
      username: '用户名已被占用，请换一个用户名。',
      email: 'Enter a valid email address.',
      confirmPassword: '请再次输入密码',
    });
  });
});

describe('authApi.login', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('follows the authentik authorization redirect and parses a custom-scheme callback', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    let state = '';
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      requests.push({ url, init });

      if (url.includes('/flows/executor/')) {
        if (requests.filter(request => request.url.includes('/flows/executor/')).length === 1) {
          const flowQuery = new URL(url).searchParams.get('query') || '';
          state = new URLSearchParams(flowQuery).get('state') || '';
          return jsonResponse(
            { component: 'ak-stage-identification' },
            { 'set-cookie': 'authentik_session=temporary; Path=/; HttpOnly' },
          );
        }
        if (requests.filter(request => request.url.includes('/flows/executor/')).length === 2) {
          return jsonResponse({ component: 'ak-stage-password' });
        }
        return jsonResponse({ component: 'xak-flow-redirect', to: '/application/o/authorize/?client_id=test' });
      }

      if (url.includes('/application/o/authorize/')) {
        return {
          ok: false,
          status: 302,
          headers: new Headers({ location: `diethealth://oauth/callback/?code=authorization-code&state=${state}` }),
          text: async () => '',
          json: async () => ({}),
        } as Response;
      }

      return jsonResponse({
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        token_type: 'Bearer',
        expires_in: 300,
      });
    }) as typeof fetch;

    const tokens = await authApi.login({ username: 'test-user', password: 'test-password' });

    expect(tokens.accessToken).toBe('access-token');
    expect(requests).toHaveLength(5);
    const flowQuery = new URL(requests[0].url).searchParams.get('query') || '';
    expect(new URLSearchParams(flowQuery).get('scope')).toBe('openid email profile offline_access');
    // 会话依赖 RN 原生 cookie（include），由 OkHttp 自动保存/回传 authentik_session
    expect(requests[1].init?.credentials).toBe('include');
    const firstFlowHeaders = requests[0].init?.headers as Record<string, string>;
    const secondFlowHeaders = requests[1].init?.headers as Record<string, string>;
    expect(firstFlowHeaders.Origin).toBe('https://auth.lovedage.com:8093');
    expect(secondFlowHeaders.Origin).toBe('https://auth.lovedage.com:8093');
    expect(firstFlowHeaders.Referer).toBe(
      `https://auth.lovedage.com:8093/if/flow/default-authentication-flow/?query=${encodeURIComponent(flowQuery)}`,
    );
    expect(secondFlowHeaders.Referer).toBe(firstFlowHeaders.Referer);
    expect((requests[3].init as RequestInit & { redirect?: string }).redirect).toBe('manual');
    const authorizeHeaders = requests[3].init?.headers as Record<string, string>;
    const tokenHeaders = requests[4].init?.headers as Record<string, string>;
    expect(authorizeHeaders.Origin).toBeUndefined();
    expect(authorizeHeaders.Referer).toBeUndefined();
    expect(tokenHeaders.Origin).toBeUndefined();
    expect(tokenHeaders.Referer).toBeUndefined();
  });
});

describe('authApi.register', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('submits Authentik nickname and password confirmation fields', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      requests.push({ url, init });
      if (requests.length === 1) {
        return jsonResponse({
          component: 'ak-stage-prompt',
          fields: [
            { field_key: 'username' },
            { field_key: 'nickname' },
            { field_key: 'email' },
            { field_key: 'password' },
            { field_key: 'password-repeat' },
          ],
        }, { 'x-authentik-id': 'registration-flow-id' });
      }
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' });

    const body = JSON.parse(String(requests[1].init?.body));
    expect(body).toMatchObject({
      component: 'ak-stage-prompt',
      username: 'new-user',
      nickname: 'new-user',
      email: 'new@example.com',
      password: 'secret123',
      'password-repeat': 'secret123',
    });
    expect((requests[1].init as RequestInit & { redirect?: string }).redirect).toBe('manual');
    const getFlowHeaders = requests[0].init?.headers as Record<string, string>;
    const postFlowHeaders = requests[1].init?.headers as Record<string, string>;
    expect(getFlowHeaders.Origin).toBe('https://auth.lovedage.com:8093');
    expect(postFlowHeaders.Origin).toBe('https://auth.lovedage.com:8093');
    expect(requests[0].url).toBe('https://auth.lovedage.com:8093/api/v3/flows/executor/email-registration/');
    expect(getFlowHeaders.Referer).toBe('https://auth.lovedage.com:8093/if/flow/email-registration/?query=');
    expect(postFlowHeaders.Referer).toBe(getFlowHeaders.Referer);
    expect(getFlowHeaders.Accept).toBe('application/json');
    expect(postFlowHeaders.Accept).toBe('application/json');
    expect(postFlowHeaders['x-authentik-id']).toBe('registration-flow-id');
    expect(requests.map(request => request.init?.method)).toEqual(['GET', 'POST']);
  });

  it('does not accept an unknown enrollment redirect as registration success', async () => {
    let step = 0;
    globalThis.fetch = jest.fn(async () => {
      step += 1;
      if (step === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      return {
        ok: false,
        status: 302,
        headers: new Headers({ location: '/if/flow/email-registration/' }),
        text: async () => '',
        json: async () => ({}),
      } as Response;
    }) as typeof fetch;

    await expect(
      authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }),
    ).rejects.toThrow('没有进入邮箱验证步骤');
  });

  it('follows a same-executor stage redirect with GET without repeating the form POST', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push({ url: String(input), init });
      if (requests.length === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      if (requests.length === 2) {
        return {
          ok: false,
          status: 302,
          headers: new Headers({ location: '/api/v3/flows/executor/email-registration/' }),
          text: async () => '',
        } as Response;
      }
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await expect(
      authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }),
    ).resolves.toMatchObject({ status: 'verification_required' });
    expect(requests.map(request => request.init?.method)).toEqual(['GET', 'POST', 'GET']);
    expect(requests.filter(request => request.init?.method === 'POST')).toHaveLength(1);
    expect(requests[2].init?.body).toBeUndefined();
  });

  it('follows consecutive same-executor stage redirects with GET only', async () => {
    const methods: Array<string | undefined> = [];
    let step = 0;
    globalThis.fetch = jest.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      step += 1;
      methods.push(init?.method);
      if (step === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      if (step <= 3) {
        return {
          ok: false,
          status: 302,
          headers: new Headers({
            location: '/api/v3/flows/executor/email-registration/',
            'x-authentik-id': `flow-${step}`,
          }),
          text: async () => '',
        } as Response;
      }
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await expect(
      authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }),
    ).resolves.toMatchObject({ status: 'verification_required' });
    expect(methods).toEqual(['GET', 'POST', 'GET', 'GET']);
  });

  it('stops at the email stage and reports registration as waiting for verification', async () => {
    let step = 0;
    globalThis.fetch = jest.fn(async () => {
      step += 1;
      if (step === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await expect(authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' })).resolves.toEqual({
      status: 'verification_required',
      username: 'new-user',
      email: 'new@example.com',
    });
    expect(step).toBe(2);
  });

  it('treats email-sent on the email stage as successful and never posts the stage again', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push({ url: String(input), init });
      if (requests.length === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      return jsonResponse({
        component: 'ak-stage-email',
        response_errors: { non_field_errors: [{ string: 'email-sent', code: 'email-sent' }] },
      });
    }) as typeof fetch;

    await expect(authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }))
      .resolves.toMatchObject({ status: 'verification_required' });
    expect(requests).toHaveLength(2);
  });

  it('does not hide unrelated errors returned by the email stage', async () => {
    let step = 0;
    globalThis.fetch = jest.fn(async () => {
      step += 1;
      if (step === 1) return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      return jsonResponse({
        component: 'ak-stage-email',
        response_errors: { non_field_errors: [{ string: 'Email delivery failed.', code: 'delivery-failed' }] },
      });
    }) as typeof fetch;

    await expect(authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }))
      .rejects.toThrow('Email delivery failed.');
    expect(step).toBe(2);
  });

  it('shares one in-flight registration for the same normalized username and email', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    let finishPost!: (response: Response) => void;
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push({ url: String(input), init });
      if (requests.length === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      return new Promise<Response>(resolve => { finishPost = resolve; });
    }) as typeof fetch;

    const first = authApi.register({ username: ' New-User ', email: 'NEW@example.com', password: 'secret123' });
    const second = authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' });
    while (!finishPost) await Promise.resolve();
    finishPost(jsonResponse({ component: 'ak-stage-email' }));

    await expect(Promise.all([first, second])).resolves.toHaveLength(2);
    expect(requests).toHaveLength(2);
  });

  it('sends the x-authentik-id from the GET response on subsequent POSTs', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      requests.push({ url, init });
      if (requests.length === 1) {
        return jsonResponse(
          {
            component: 'ak-stage-prompt',
            fields: [{ field_key: 'username' }, { field_key: 'email' }, { field_key: 'password' }, { field_key: 'password-repeat' }],
          },
          { 'x-authentik-id': 'flow-session-abc' },
        );
      }
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' });

    const postInit = requests[1].init as { headers?: Record<string, string> };
    expect(postInit?.headers?.['x-authentik-id']).toBe('flow-session-abc');
  });

  it('stops retrying when the flow returns the same prompt without errors', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      requests.push({ url, init });
      // 每次请求都返回同一个 prompt 且无错误 → flow 卡死未推进
      return jsonResponse({
        component: 'ak-stage-prompt',
        fields: [
          { field_key: 'username' },
          { field_key: 'nickname' },
          { field_key: 'email' },
          { field_key: 'password' },
          { field_key: 'password-repeat' },
        ],
      });
    }) as typeof fetch;

    await expect(
      authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }),
    ).rejects.toThrow('认证流程未正常推进');

    // 只发生一次 GET + 一次 POST，随后停止（不再盲目重发相同数据）
    expect(requests).toHaveLength(2);
  });

  it('surfaces prompt response errors without sending another request', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push({ url: String(input), init });
      if (requests.length === 1) {
        return jsonResponse({ component: 'ak-stage-prompt', fields: [{ field_key: 'username' }] });
      }
      return jsonResponse({
        component: 'ak-stage-prompt',
        fields: [{ field_key: 'username' }],
        response_errors: { username: [{ string: 'Username is already taken.', code: 'invalid' }] },
      });
    }) as typeof fetch;

    await expect(authApi.register({ username: 'taken', email: 'taken@example.com', password: 'secret123' }))
      .rejects.toThrow('用户名已被占用');
    expect(requests).toHaveLength(2);
  });

  it('keeps the request ID and explains likely CSRF rejection from a flow error', async () => {
    globalThis.fetch = jest.fn(async () =>
      jsonResponse({ component: 'ak-stage-flow-error', request_id: 'csrf-request-id' }),
    ) as typeof fetch;

    await expect(
      authApi.register({ username: 'new-user', email: 'new@example.com', password: 'secret123' }),
    ).rejects.toThrow(/CSRF.*csrf-request-id/);
  });
});

describe('authApi.resendVerificationEmail', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('submits an email to the resend flow and stops at the email stage', async () => {
    const requests: Array<{ url: string; init?: RequestInit }> = [];
    globalThis.fetch = jest.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      requests.push({ url: String(input), init });
      if (requests.length === 1) return jsonResponse({ component: 'ak-stage-identification' });
      return jsonResponse({ component: 'ak-stage-email' });
    }) as typeof fetch;

    await expect(authApi.resendVerificationEmail('  user@example.com  ')).resolves.toBeUndefined();

    expect(requests).toHaveLength(2);
    expect(requests[0].url).toContain('/flows/executor/email-verification-resend/');
    expect(JSON.parse(String(requests[1].init?.body))).toEqual({
      component: 'ak-stage-identification',
      uid_field: 'user@example.com',
    });
    const getHeaders = requests[0].init?.headers as Record<string, string>;
    const postHeaders = requests[1].init?.headers as Record<string, string>;
    expect(getHeaders.Origin).toBe('https://auth.lovedage.com:8093');
    expect(getHeaders.Referer).toBe('https://auth.lovedage.com:8093/if/flow/email-verification-resend/?query=');
    expect(postHeaders.Referer).toBe(getHeaders.Referer);
  });
});
