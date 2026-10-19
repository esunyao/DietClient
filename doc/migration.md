# UI 迁移对照

只读来源：DietClient-ReactNative 的 src/navigation/AppNavigator.tsx、src/shared/theme/tokens.ts、src/features/{auth,diet,profile}/screens。本阶段目标如下，验收记录见文末。

| RN 页面 | Flutter feature / 同名页面 |
|---|---|
| HomeScreen | home |
| RecognitionScreen | capture |
| MealHistoryScreen、MealDetailScreen、MealCorrectionScreen | meals |
| MealPlanScreen | meal_plan |
| TrendsScreen、ReportsScreen、ScoreDetailScreen | insights |
| LoginScreen、RegisterScreen、VerifyEmailScreen、EmailVerifiedScreen | auth |
| ProfileScreen、EditProfileScreen、HealthRecordsScreen、HealthRecordFormScreen、AiNutritionConsentScreen | profile |

底栏顺序：首页、记录、配餐、趋势、报告、我的。详情与表单独立打开并隐藏底栏；认证界面从我的进入预览，不拦截主应用。页面标记 UI 演示；交互只更新内存或打开明确的演示预览。

迁移布局、主题、信息层级、表单验证、导航、图表、分段与浮层。排除会话、Token、真实授权、API、上传、相机、同步与原生玻璃。

测试或 Web 截图仅证明对应环境的结果，不代表 RN 像素级一致，也不替代移动真机性能和业务验收。
