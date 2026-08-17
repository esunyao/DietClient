export type DietPageId = 'recognition' | 'mealHistory' | 'mealDetail' | 'mealCorrection';

export interface PageDefinition {
  title: string;
  subtitle?: string;
  showBottomTab: boolean;
  showBack: boolean;
  root: boolean;
}

export const pageRegistry: Record<DietPageId, PageDefinition> = {
  recognition: { title: '识别这一餐', subtitle: '个人拍照与食堂菜单演示', showBottomTab: true, showBack: false, root: true },
  mealHistory: { title: '饮食记录', subtitle: '筛选、搜索与分页查询', showBottomTab: false, showBack: true, root: false },
  mealDetail: { title: '本餐营养报告', subtitle: 'AI 识别结果与人工修正记录', showBottomTab: false, showBack: true, root: false },
  mealCorrection: { title: '修正本餐', subtitle: '保存后会重算餐次与每日汇总', showBottomTab: false, showBack: true, root: false },
};

export function isBottomTabVisibleForDietRoute(routeName?: string): boolean {
  // React Navigation 首帧可能还未提供嵌套 Stack state；Recognition 是该 Tab 的唯一根页。
  return (routeName ?? 'Recognition') === 'Recognition';
}
