const healthRecordIdKeys = new Set([
  'measurementId',
  'goalId',
  'allergyId',
  'conditionId',
  'restrictionId',
  'foodId',
  'mealId',
  'imageId',
  'itemId',
]);

const unsafeIntegerPattern =
  /"(measurementId|goalId|allergyId|conditionId|restrictionId|foodId|mealId|imageId|itemId)"\s*:\s*(-?\d{16,})/g;

/**
 * Orion 的健康记录主键是 64 位雪花 ID。JSON.parse 会把它变成 number 并丢失低位，
 * 这里在解析前只给已定义的业务 ID 加引号，其他数值仍维持普通 number。
 */
export function parseApiJson(raw: unknown): unknown {
  if (typeof raw !== 'string' || raw.length === 0) return raw;
  return JSON.parse(raw.replace(unsafeIntegerPattern, '"$1":"$2"'), (key, value) => {
    return healthRecordIdKeys.has(key) && typeof value === 'number' ? String(value) : value;
  });
}
