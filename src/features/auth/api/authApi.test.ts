import { authApi, createPkcePair, resolveRegistrationNickname } from './authApi';

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
    expect(requests[1].init?.credentials).toBe('omit');
    expect((requests[1].init?.headers as Record<string, string>).Cookie).toContain('authentik_session=temporary');
    expect((requests[3].init as RequestInit & { redirect?: string }).redirect).toBe('manual');
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
        });
      }
      return jsonResponse({ component: 'xak-flow-redirect', to: '/flows/-/cancel/' });
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
  });
});
