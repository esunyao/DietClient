import { getHealthRecordDeleteSummary } from './healthRecordDeleteSummary';

describe('getHealthRecordDeleteSummary', () => {
  it.each([
    ['measurement', { measuredAt: '2026-08-12T08:00:00Z', weightKg: 62.3, bodyFatPercentage: null }, '身体测量', '2026-08-12 · 62.3 kg'],
    ['goal', { goalType: 'weight_loss', targetWeightKg: 60, targetBodyFatPercentage: null }, '健康目标', '减重 · 60 kg'],
    ['allergy', { allergenName: '花生', severity: 'moderate' }, '过敏记录', '花生 · 中等'],
    ['condition', { conditionName: '哮喘', status: 'active' }, '疾病记录', '哮喘 · 进行中'],
    ['restriction', { restrictionName: '不吃牛肉', category: 'preference' }, '饮食限制', '不吃牛肉 · 个人偏好'],
  ])('%s summary is user-facing', (kind, record, title, summary) => {
    const result = getHealthRecordDeleteSummary(kind as never, record as never);
    expect(result.title).toContain(title);
    expect(result.summary).toBe(summary);
    expect(result.detail).not.toMatch(/Orion|API|code|ID/i);
  });
});
