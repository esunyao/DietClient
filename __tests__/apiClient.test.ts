import type { AxiosResponse } from 'axios';

// 网络层测试不依赖设备原生存储，实现与 App 运行时的存储边界隔离。
jest.mock('@react-native-async-storage/async-storage', () => ({
  __esModule: true,
  default: { getItem: jest.fn(), setItem: jest.fn(), removeItem: jest.fn() },
}));

import { ApiError, assertApiSuccess, buildAuthorizationHeader, shouldRefreshAfterUnauthorized, unwrapApiResponse } from '../src/shared/api/client';
import type { ApiEnvelope } from '../src/shared/types/api';

function response<T>(data: ApiEnvelope<T>): AxiosResponse<ApiEnvelope<T>> {
  return { data } as AxiosResponse<ApiEnvelope<T>>;
}

describe('API 响应与认证规则', () => {
  test('只从 code=200 的响应中解包 data', () => {
    expect(unwrapApiResponse(response({ code: 200, message: 'Success', data: { nickname: '小安' } }))).toEqual({ nickname: '小安' });
  });

  test('业务失败保留服务端提示', () => {
    expect(() => unwrapApiResponse(response({ code: 400, message: '用户名已被注册', data: null, traceId: 'trace-1' }))).toThrow(ApiError);
  });

  test('无 data 的成功接口可以通过断言', () => {
    expect(() => assertApiSuccess(response({ code: 200, message: '密码修改成功', data: null }))).not.toThrow();
  });

  test('请求会添加 Bearer Token，且刷新接口不会触发二次刷新', () => {
    expect(buildAuthorizationHeader('access-token')).toEqual({ Authorization: 'Bearer access-token' });
    expect(shouldRefreshAfterUnauthorized(401, { url: 'v1/users/self' })).toBe(true);
    expect(shouldRefreshAfterUnauthorized(401, { url: 'v1/auth/refresh' })).toBe(false);
    expect(shouldRefreshAfterUnauthorized(401, { url: 'v1/users/self', _hasRetried: true })).toBe(false);
  });
});
