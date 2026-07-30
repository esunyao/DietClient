import React from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

/**
 * -----------------------------------------------------------------------------
 * 🎓 React Native 样板代码：首页 Dashboard (HomeScreen)
 * -----------------------------------------------------------------------------
 * 参考原型: 01-home.html
 * 重点学习概念：
 * 1. Flexbox 布局：React Native 默认 flex-direction 为 column (垂直排列)
 * 2. 基础组件：View (类似 div), Text (类似 span/p), ScrollView (可滚动区域), TouchableOpacity (按钮/可点击区域)
 * 3. 样式管理：StyleSheet.create (类似 CSS 类定义，推荐性能优化)
 * -----------------------------------------------------------------------------
 */

export function HomeScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" backgroundColor="#f5f5f7" />

      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
      >
        {/* ================= 1. 顶部 Header / 问候语 ================= */}
        <View style={styles.header}>
          <Text style={styles.dateText}>2026年7月25日 · 下午好</Text>
          <Text style={styles.greetingTitle}>今天吃得怎么样？</Text>
        </View>

        {/* ================= 2. 健康评分卡片 (Score Card) ================= */}
        <View style={styles.scoreCard}>
          {/* 左侧分数圆环模拟区域 */}
          <View style={styles.scoreRing}>
            <Text style={styles.scoreValue}>78</Text>
            <Text style={styles.scoreLabel}>健康评分</Text>
          </View>

          {/* 右侧健康分析提示 */}
          <View style={styles.scoreInfo}>
            <Text style={styles.scoreTitle}>状态良好 👍</Text>
            <Text style={styles.scoreDesc}>
              今日热量摄入适中，蛋白质偏低。建议晚餐增加优质蛋白，如鸡胸肉或豆腐。
            </Text>

            {/* 标签列表 */}
            <View style={styles.badgeList}>
              <View style={[styles.badge, styles.badgeGreen]}>
                <Text style={styles.badgeGreenText}>✓ 热量适配 85</Text>
              </View>
              <View style={[styles.badge, styles.badgeOrange]}>
                <Text style={styles.badgeOrangeText}>! 营养均衡 72</Text>
              </View>
            </View>
          </View>
        </View>

        {/* ================= 3. 预警提示条 (Risk Bar) ================= */}
        <View style={styles.riskBar}>
          <Text style={styles.riskText}>
            ⚠️ 您今日钠摄入已达目标的 82%，晚餐请注意控盐
          </Text>
          <TouchableOpacity style={styles.riskButton} activeOpacity={0.8}>
            <Text style={styles.riskButtonText}>查看建议</Text>
          </TouchableOpacity>
        </View>

        {/* ================= 4. 快捷操作入口 (Quick Actions) ================= */}
        <View style={styles.actionsGrid}>
          {/* 主动作：拍照识别 */}
          <TouchableOpacity
            style={[styles.actionBtn, styles.actionPrimary]}
            activeOpacity={0.85}
          >
            <Text style={styles.actionIconPrimary}>📷</Text>
            <Text style={styles.actionTitlePrimary}>拍照识别</Text>
            <Text style={styles.actionDescPrimary}>拍摄菜品获取分析</Text>
          </TouchableOpacity>

          {/* 手动记录 */}
          <TouchableOpacity style={styles.actionBtn} activeOpacity={0.7}>
            <Text style={styles.actionIcon}>✍️</Text>
            <Text style={styles.actionTitle}>手动记录</Text>
            <Text style={styles.actionDesc}>输入菜品名称</Text>
          </TouchableOpacity>

          {/* 营养处方 */}
          <TouchableOpacity style={styles.actionBtn} activeOpacity={0.7}>
            <Text style={styles.actionIcon}>🥗</Text>
            <Text style={styles.actionTitle}>营养处方</Text>
            <Text style={styles.actionDesc}>推荐食谱配餐</Text>
          </TouchableOpacity>

          {/* 今日目标 */}
          <TouchableOpacity style={styles.actionBtn} activeOpacity={0.7}>
            <Text style={styles.actionIcon}>🎯</Text>
            <Text style={styles.actionTitle}>今日目标</Text>
            <Text style={styles.actionDesc}>调整营养目标</Text>
          </TouchableOpacity>
        </View>

        {/* ================= 5. 今日营养数据 (Nutrition Stats) ================= */}
        <Text style={styles.sectionTitle}>今日营养摄入</Text>
        <View style={styles.nutritionGrid}>
          <NutritionCard label="热量" value="1,280" unit="kcal" color="#ff9500" progress={0.65} />
          <NutritionCard label="蛋白质" value="38" unit="g" color="#34c759" progress={0.45} />
          <NutritionCard label="碳水化合物" value="186" unit="g" color="#5856d6" progress={0.80} />
          <NutritionCard label="脂肪" value="42" unit="g" color="#ff3b30" progress={0.55} />
        </View>

        {/* ================= 6. 今日饮食记录 (Meal List) ================= */}
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>今日饮食记录</Text>
          <TouchableOpacity>
            <Text style={styles.moreText}>全部 ＞</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.mealList}>
          <MealItem
            icon="🥗"
            name="鸡胸肉沙拉 + 全麦面包"
            meta="午餐 · 12:30 · 570 kcal"
            score="85分"
            scoreType="good"
          />
          <MealItem
            icon="🥣"
            name="燕麦粥 + 水煮蛋 + 蓝莓"
            meta="早餐 · 08:15 · 380 kcal"
            score="92分"
            scoreType="good"
          />
          <MealItem
            icon="☕"
            name="黑咖啡 + 坚果"
            meta="加餐 · 10:00 · 180 kcal"
            score="78分"
            scoreType="warn"
          />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

// -----------------------------------------------------------------------------
// 🧩 子组件：营养度量小卡片
// -----------------------------------------------------------------------------
function NutritionCard({
  label,
  value,
  unit,
  color,
  progress,
}: {
  label: string;
  value: string;
  unit: string;
  color: string;
  progress: number;
}) {
  return (
    <View style={styles.nutriCard}>
      <Text style={styles.nutriLabel}>{label}</Text>
      <Text style={styles.nutriValue}>
        {value} <Text style={styles.nutriUnit}>{unit}</Text>
      </Text>
      {/* 进度条背景 */}
      <View style={styles.progressBarBackground}>
        {/* 动态进度 fill */}
        <View
          style={[
            styles.progressBarFill,
            { backgroundColor: color, width: `${progress * 100}%` },
          ]}
        />
      </View>
    </View>
  );
}

// -----------------------------------------------------------------------------
// 🧩 子组件：单条餐饮记录
// -----------------------------------------------------------------------------
function MealItem({
  icon,
  name,
  meta,
  score,
  scoreType,
}: {
  icon: string;
  name: string;
  meta: string;
  score: string;
  scoreType: 'good' | 'warn';
}) {
  return (
    <View style={styles.mealCard}>
      <Text style={styles.mealIcon}>{icon}</Text>
      <View style={styles.mealInfo}>
        <Text style={styles.mealName}>{name}</Text>
        <Text style={styles.mealMeta}>{meta}</Text>
      </View>
      <View
        style={[
          styles.scoreBadge,
          scoreType === 'good' ? styles.scoreGood : styles.scoreWarn,
        ]}
      >
        <Text
          style={[
            styles.scoreBadgeText,
            scoreType === 'good' ? styles.scoreGoodText : styles.scoreWarnText,
          ]}
        >
          {score}
        </Text>
      </View>
    </View>
  );
}

// -----------------------------------------------------------------------------
// 🎨 样式定义 (StyleSheet)
// -----------------------------------------------------------------------------
const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f5f5f7',
  },
  container: {
    flex: 1,
  },
  contentContainer: {
    padding: 16,
    paddingBottom: 40,
  },

  // 1. Header
  header: {
    marginBottom: 20,
  },
  dateText: {
    fontSize: 13,
    color: '#86868b',
    marginBottom: 4,
  },
  greetingTitle: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1d1d1f',
  },

  // 2. Score Card
  scoreCard: {
    backgroundColor: '#1d1d1f',
    borderRadius: 20,
    padding: 20,
    flexDirection: 'row', // 水平排列 (左边圆环，右边文字)
    alignItems: 'center',
    marginBottom: 16,
  },
  scoreRing: {
    width: 90,
    height: 90,
    borderRadius: 45,
    borderWidth: 6,
    borderColor: '#34c759',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  scoreValue: {
    fontSize: 30,
    fontWeight: '700',
    color: '#ffffff',
  },
  scoreLabel: {
    fontSize: 10,
    color: 'rgba(255, 255, 255, 0.6)',
  },
  scoreInfo: {
    flex: 1, // 占据剩余宽度
  },
  scoreTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#ffffff',
    marginBottom: 4,
  },
  scoreDesc: {
    fontSize: 12,
    color: 'rgba(255, 255, 255, 0.7)',
    lineHeight: 16,
    marginBottom: 8,
  },
  badgeList: {
    flexDirection: 'row',
    gap: 6,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
  },
  badgeGreen: {
    backgroundColor: 'rgba(52, 199, 89, 0.2)',
  },
  badgeGreenText: {
    color: '#34c759',
    fontSize: 10,
    fontWeight: '600',
  },
  badgeOrange: {
    backgroundColor: 'rgba(255, 149, 0, 0.2)',
  },
  badgeOrangeText: {
    color: '#ff9500',
    fontSize: 10,
    fontWeight: '600',
  },

  // 3. Risk Bar
  riskBar: {
    backgroundColor: '#fff3e0',
    borderColor: '#ffe0b2',
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  riskText: {
    fontSize: 12,
    color: '#e65100',
    flex: 1,
    marginRight: 8,
  },
  riskButton: {
    backgroundColor: '#ff9500',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  riskButtonText: {
    color: '#ffffff',
    fontSize: 11,
    fontWeight: '600',
  },

  // 4. Quick Actions
  actionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap', // 允许换行，实现 2x2 网格
    gap: 10,
    marginBottom: 24,
  },
  actionBtn: {
    width: '48%', // 一行放两个卡片
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.04)',
  },
  actionPrimary: {
    backgroundColor: '#0071e3',
  },
  actionIcon: {
    fontSize: 22,
    marginBottom: 8,
  },
  actionIconPrimary: {
    fontSize: 22,
    marginBottom: 8,
  },
  actionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 2,
  },
  actionTitlePrimary: {
    fontSize: 14,
    fontWeight: '600',
    color: '#ffffff',
    marginBottom: 2,
  },
  actionDesc: {
    fontSize: 11,
    color: '#86868b',
  },
  actionDescPrimary: {
    fontSize: 11,
    color: 'rgba(255, 255, 255, 0.8)',
  },

  // Section Universal
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 12,
  },
  moreText: {
    fontSize: 12,
    color: '#0071e3',
  },

  // 5. Nutrition Grid
  nutritionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginBottom: 20,
  },
  nutriCard: {
    width: '48%',
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 12,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.04)',
  },
  nutriLabel: {
    fontSize: 12,
    color: '#86868b',
    marginBottom: 4,
  },
  nutriValue: {
    fontSize: 20,
    fontWeight: '700',
    color: '#1d1d1f',
    marginBottom: 8,
  },
  nutriUnit: {
    fontSize: 12,
    color: '#86868b',
    fontWeight: 'normal',
  },
  progressBarBackground: {
    height: 4,
    backgroundColor: '#f0f0f0',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 2,
  },

  // 6. Meal List
  mealList: {
    gap: 10,
  },
  mealCard: {
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.04)',
  },
  mealIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  mealInfo: {
    flex: 1,
  },
  mealName: {
    fontSize: 14,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 2,
  },
  mealMeta: {
    fontSize: 11,
    color: '#86868b',
  },
  scoreBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 10,
  },
  scoreGood: {
    backgroundColor: '#f0f8f0',
  },
  scoreGoodText: {
    color: '#34c759',
  },
  scoreWarn: {
    backgroundColor: '#fff8f0',
  },
  scoreWarnText: {
    color: '#ff9500',
  },
  scoreBadgeText: {
    fontSize: 11,
    fontWeight: '600',
  },
});
