jest.mock('../api/healthApi', () => ({
  healthApi: {
    bodyMeasurements: { list: jest.fn() },
    healthGoals: { list: jest.fn() },
    allergies: { list: jest.fn() },
    medicalConditions: { list: jest.fn() },
    dietaryRestrictions: { list: jest.fn() },
  },
}));

import { healthApi } from '../api/healthApi';
import {
  getCachedHealthRecords,
  getHealthRecords,
  invalidateHealthRecords,
  removeHealthRecord,
  upsertHealthRecord,
} from './healthRecordsCache';

const mockListMeasurements = healthApi.bodyMeasurements.list as jest.Mock;
const mockListGoals = healthApi.healthGoals.list as jest.Mock;
const mockListAllergies = healthApi.allergies.list as jest.Mock;
const mockListConditions = healthApi.medicalConditions.list as jest.Mock;
const mockListRestrictions = healthApi.dietaryRestrictions.list as jest.Mock;

describe('healthRecordsCache', () => {
  beforeEach(() => {
    invalidateHealthRecords();
    jest.clearAllMocks();
    mockListMeasurements.mockResolvedValue([]);
    mockListGoals.mockResolvedValue([]);
    mockListAllergies.mockResolvedValue([]);
    mockListConditions.mockResolvedValue([]);
    mockListRestrictions.mockResolvedValue([]);
  });

  it('shares one request and returns the cached snapshot', async () => {
    const [first, second] = await Promise.all([getHealthRecords(), getHealthRecords()]);

    expect(first).toBe(second);
    expect(getCachedHealthRecords()).toBe(first);
    expect(mockListMeasurements).toHaveBeenCalledTimes(1);
    expect(mockListGoals).toHaveBeenCalledTimes(1);
    expect(mockListAllergies).toHaveBeenCalledTimes(1);
    expect(mockListConditions).toHaveBeenCalledTimes(1);
    expect(mockListRestrictions).toHaveBeenCalledTimes(1);

    await getHealthRecords();
    expect(mockListMeasurements).toHaveBeenCalledTimes(1);
  });

  it('fetches fresh data after invalidation', async () => {
    await getHealthRecords();
    invalidateHealthRecords();
    await getHealthRecords();

    expect(mockListMeasurements).toHaveBeenCalledTimes(2);
    expect(mockListGoals).toHaveBeenCalledTimes(2);
  });

  it('updates and removes one cached record without another request', async () => {
    mockListGoals.mockResolvedValue([{ goalId: 'goal-a', goalType: 'maintain' }]);
    await getHealthRecords();

    upsertHealthRecord('goals', { goalId: 'goal-a', goalType: 'weight_loss' } as never);
    upsertHealthRecord('goals', { goalId: 'goal-b', goalType: 'health_improve' } as never);
    removeHealthRecord('goals', 'goal-a');

    expect(getCachedHealthRecords()?.goals).toEqual([
      { goalId: 'goal-b', goalType: 'health_improve' },
    ]);
    expect(mockListGoals).toHaveBeenCalledTimes(1);
  });
});
