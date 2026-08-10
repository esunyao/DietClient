import { authApi, createPkcePair } from './authApi';

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
    expect(requests[1].init?.credentials).toBe('omit');
    expect((requests[1].init?.headers as Record<string, string>).Cookie).toContain('authentik_session=temporary');
    expect((requests[3].init as RequestInit & { redirect?: string }).redirect).toBe('manual');
  });
});
