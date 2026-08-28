import 'react-native-get-random-values';

export function localDateFromDate(date = new Date()): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

export function resolveDeviceTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

export function createIdempotencyKey(): string {
  const bytes = new Uint8Array(16);
  const cryptoApi = (
    globalThis as unknown as { crypto?: { getRandomValues: (value: Uint8Array) => Uint8Array } }
  ).crypto;
  if (!cryptoApi?.getRandomValues) throw new Error('当前设备不支持安全随机数，无法创建采集会话。');
  cryptoApi.getRandomValues(bytes);
  bytes[6] = (bytes[6] % 16) + 64;
  bytes[8] = (bytes[8] % 64) + 128;
  const hex = Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(
    16,
    20,
  )}-${hex.slice(20)}`;
}
