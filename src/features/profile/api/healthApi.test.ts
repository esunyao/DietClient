jest.mock('../../../shared/api/client', () => ({
  apiClient: {
    get: jest.fn(),
    post: jest.fn(),
    patch: jest.fn(),
    put: jest.fn(),
    delete: jest.fn(),
  },
  unwrapApiResponse: jest.fn(),
  assertApiSuccess: jest.fn(),
}));

import { apiClient, assertApiSuccess, unwrapApiResponse } from '../../../shared/api/client';
import { healthApi } from './healthApi';

const patchMock = apiClient.patch as unknown as jest.Mock;
const deleteMock = apiClient.delete as unknown as jest.Mock;
const unwrapMock = unwrapApiResponse as unknown as jest.Mock;
const assertMock = assertApiSuccess as unknown as jest.Mock;
const snowflakeId = '2086475596958904300';

describe('healthApi record paths', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    unwrapMock.mockImplementation(response => response.data.data);
  });

  it('uses the exact 64-bit ID from Orion for an update', async () => {
    const payload = {
      conditionCode: 'patchcond',
      conditionName: '补丁疾病',
      status: 'resolved' as const,
      source: 'self_reported' as const,
    };
    patchMock.mockResolvedValue({ data: { data: { conditionId: snowflakeId } } });

    await healthApi.medicalConditions.update(snowflakeId, payload);

    expect(patchMock).toHaveBeenCalledWith(
      `v1/users/self/medical-conditions/${snowflakeId}`,
      payload,
    );
  });

  it('uses the exact 64-bit ID from Orion for a delete', async () => {
    deleteMock.mockResolvedValue({ data: { code: 200 } });

    await healthApi.medicalConditions.remove(snowflakeId);

    expect(deleteMock).toHaveBeenCalledWith(`v1/users/self/medical-conditions/${snowflakeId}`);
    expect(assertMock).toHaveBeenCalled();
  });
});
