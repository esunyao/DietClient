import {
  isPercentageInput,
  normalizePercentageInput,
  percentageFromSlider,
} from './percentage';

describe('percentage validation', () => {
  test.each([
    ['0', '0.0'],
    ['0.0', '0.0'],
    ['20', '20.0'],
    ['20.5', '20.5'],
    ['100', '100.0'],
    ['100.0', '100.0'],
  ])('accepts and normalizes %s', (input, expected) => {
    expect(isPercentageInput(input)).toBe(true);
    expect(normalizePercentageInput(input)).toBe(expected);
  });

  test.each(['-1', '100.1', '20.55', 'abc', '20..5', ' 20', '20 '])(
    'rejects %s',
    input => {
      expect(isPercentageInput(input)).toBe(false);
      expect(normalizePercentageInput(input)).toBeNull();
    },
  );

  it('allows an empty or trailing-decimal draft without producing a stored empty value', () => {
    expect(isPercentageInput('')).toBe(true);
    expect(normalizePercentageInput('')).toBeNull();
    expect(isPercentageInput('20.')).toBe(true);
    expect(normalizePercentageInput('20.')).toBe('20.0');
  });

  it('keeps slider values in range and at one decimal place', () => {
    expect(percentageFromSlider(20.54)).toBe('20.5');
    expect(percentageFromSlider(-1)).toBe('0.0');
    expect(percentageFromSlider(101)).toBe('100.0');
  });
});
