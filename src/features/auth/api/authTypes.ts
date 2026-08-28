/** Authentik OIDC Token Endpoint 返回值；由平台凭证存储负责持久化。 */
export interface OidcTokenSet {
  accessToken: string;
  refreshToken: string | null;
  tokenType: string;
  expiresIn: number;
  idToken?: string;
  obtainedAt: number;
}

/** Authentik flow executor 返回的动态步骤。 */
export interface FlowChallenge {
  component: string;
  type?: string;
  to?: string;
  request_id?: string;
  error_message?: string;
  response_errors?: Record<string, Array<{ string?: string; code?: string }>>;
  [key: string]: unknown;
}

export type FlowChallengeResponder = (challenge: FlowChallenge) => Promise<Record<string, unknown>>;

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

export interface RegistrationResult {
  status: 'verification_required';
  username: string;
  email: string;
}

export type RegistrationFieldName =
  | 'username'
  | 'displayName'
  | 'email'
  | 'password'
  | 'confirmPassword';

export type RegistrationFieldErrors = Partial<Record<RegistrationFieldName, string>>;

/** 保留服务端组件与字段错误，供页面将协议错误映射到具体表单。 */
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
