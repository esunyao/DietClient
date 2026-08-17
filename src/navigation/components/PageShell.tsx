import React from 'react';
import type { ReactNode } from 'react';

import { AppScreen, ScreenHeader } from '../../shared/components';
import { pageRegistry, type DietPageId } from '../pageRegistry';

interface PageShellProps {
  pageId: DietPageId;
  children: ReactNode;
  onBack?: () => void;
  action?: ReactNode;
}

/** 页面元数据集中管理；业务屏幕只声明 pageId，不各自复制标题和返回逻辑。 */
export function PageShell({ pageId, children, onBack, action }: PageShellProps) {
  const page = pageRegistry[pageId];
  return <AppScreen header={<ScreenHeader title={page.title} subtitle={page.subtitle} onBack={page.showBack ? onBack : undefined} action={action} />}>{children}</AppScreen>;
}
