import type { OidcTokenSet } from '../../../features/auth/api/authTypes';

/** 只接受认证流程真正需要的字段，避免损坏数据进入会话恢复。 */
export function parsePersistedTokens(raw: string | null): OidcTokenSet | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as Partial<OidcTokenSet>;
    if (
      typeof value.accessToken !== 'string' ||
      !value.accessToken ||
      (value.refreshToken !== null && typeof value.refreshToken !== 'string') ||
      typeof value.tokenType !== 'string' ||
      !value.tokenType ||
      typeof value.expiresIn !== 'number' ||
      !Number.isFinite(value.expiresIn) ||
      value.expiresIn <= 0 ||
      typeof value.obtainedAt !== 'number' ||
      !Number.isFinite(value.obtainedAt)
    )
      return null;
    return {
      accessToken: value.accessToken,
      refreshToken: value.refreshToken ?? null,
      tokenType: value.tokenType,
      expiresIn: value.expiresIn,
      idToken: typeof value.idToken === 'string' ? value.idToken : undefined,
      obtainedAt: value.obtainedAt,
    };
  } catch {
    return null;
  }
}

export function serializeTokens(tokens: OidcTokenSet): string {
  return JSON.stringify(tokens);
}
