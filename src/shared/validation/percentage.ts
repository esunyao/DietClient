export const PERCENTAGE_VALIDATION_MESSAGE = '请输入 0–100，最多一位小数';

/**
 * 输入过程校验。空字符串用于允许用户清空后重新输入；是否可以最终留空由调用方决定。
 */
export function isPercentageInput(value: string): boolean {
  if (value === '') return true;
  if (!/^\d{1,3}(?:\.\d?)?$/.test(value)) return false;

  const number = Number(value);
  return Number.isFinite(number) && number >= 0 && number <= 100;
}

/** 将合法百分比统一成一位小数；空值或非法值返回 null。 */
export function normalizePercentageInput(value: string): string | null {
  if (!value || !isPercentageInput(value)) return null;
  return Number(value).toFixed(1);
}

export function percentageFromSlider(value: number): string {
  const clamped = Math.max(0, Math.min(100, value));
  return clamped.toFixed(1);
}
