import { emptyCorrectionItem, mealToCorrectionDraft, serializeMealCorrection } from './mealCorrectionDraft';

describe('meal correction draft', () => {
  it('serializes item snapshots without food library IDs', () => {
    const item = emptyCorrectionItem(); item.displayName = '番茄炒蛋';
    expect(serializeMealCorrection({ mealType: 'lunch', consumedAt: '2026-08-17T04:00:00.000Z', timezone: 'Asia/Shanghai', notes: '', items: [item] })).toEqual(expect.objectContaining({ items: [expect.objectContaining({ displayName: '番茄炒蛋' })] }));
  });
  it('makes an editable copy of returned meal items', () => {
    const draft = mealToCorrectionDraft({ mealId: '1', captureSessionId: '2', mealType: 'lunch', consumedAt: '2026-08-17T04:00:00.000Z', timezone: 'Asia/Shanghai', localDate: '2026-08-17', notes: null, nutrients: [], createdAt: '', updatedAt: '', items: [{ itemId: '3', sequenceNo: 1, displayName: '鱼', estimatedWeightG: 100, confidence: 0.9, dataSource: 'ai', userCorrected: false, notes: null, nutrients: [{ nutrientCode: 'PROTEIN', nutrientName: '蛋白质', unit: 'g', amount: 20 }] }] });
    draft.items[0].nutrients[0].amount = 30;
    expect(draft.items[0].displayName).toBe('鱼');
  });
});
