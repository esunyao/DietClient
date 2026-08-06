/**
 * @format
 */

import { API_BASE_URL } from '../src/shared/config/appConfig';
import { colors } from '../src/shared/theme/tokens';

test('uses the Gateway address and reference design tokens', () => {
  expect(API_BASE_URL).toBe('http://localhost:8091/');
  expect(colors.blue).toBe('#0071E3');
  expect(colors.green).toBe('#34C759');
});
