import type { Allergy, BodyMeasurement } from '../../api/profileTypes';
import { getHealthRecordId } from './healthRecordAdapter';

describe('health record adapter', () => {
  it('reads the explicit identifier for each record kind', () => {
    expect(
      getHealthRecordId('measurement', { measurementId: 'measurement-1' } as BodyMeasurement),
    ).toBe('measurement-1');
    expect(getHealthRecordId('allergy', { allergyId: 'allergy-1' } as Allergy)).toBe('allergy-1');
  });
});
