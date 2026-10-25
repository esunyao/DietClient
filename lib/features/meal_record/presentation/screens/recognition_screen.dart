import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';
import 'package:diet_client/core/config/ui_preview_config.dart';

import 'native_recognition_screen.dart';

class RecognitionScreen extends ConsumerWidget {
  const RecognitionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(nativeNutritionEnabledProvider)
      ? const NativeRecognitionScreen()
      : const _DemoRecognitionScreen();
}

class _DemoRecognitionScreen extends ConsumerStatefulWidget {
  const _DemoRecognitionScreen();
  @override
  ConsumerState<_DemoRecognitionScreen> createState() =>
      _RecognitionScreenState();
}

class _RecognitionScreenState extends ConsumerState<_DemoRecognitionScreen> {
  int _mode = 0;
  int _images = 1;
  MealType _type = MealType.lunch;
  final _notes = TextEditingController();
  bool _hasDraft = true;
  bool _saving = false;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final add = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择示例餐盘',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Center(child: PlateIllustration(size: 140)),
              const SizedBox(height: 12),
              const Text('餐盘示意，仅用于本地预览，不读取相机或相册。'),
              const SizedBox(height: 20),
              AppButton(
                label: '使用此示例图片',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (add == true && mounted) {
      setState(() => _images = (_images + 1).clamp(0, 3));
    }
  }

  Future<void> _draft() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '未提交草稿 · 示例',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('昨日保存 / 1 张餐盘示意 / 午餐'),
              const SizedBox(height: 20),
              AppButton(
                label: '继续编辑此草稿',
                onPressed: () => Navigator.pop(context, 'restore'),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: '移除示例草稿',
                secondary: true,
                onPressed: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() {
      _hasDraft = false;
      if (action == 'restore') {
        _images = 1;
        _type = MealType.lunch;
        _notes.text = '清蒸、少油';
      }
    });
    showDemoMessage(
      context,
      action == 'restore' ? '已恢复到本地预览，尚未保存记录' : '已移除本地示例草稿',
    );
  }

  void _submit() {
    if (_saving || _images == 0 || !ref.read(demoProvider).aiConsent) return;
    setState(() => _saving = true);
    final id = 'capture-${DateTime.now().microsecondsSinceEpoch}';
    ref
        .read(demoProvider.notifier)
        .saveMeal(
          MealEntry(
            id: id,
            title: '餐盘示意，等待营养补充',
            type: _type,
            consumedAt: DateTime(
              demoDate.year,
              demoDate.month,
              demoDate.day,
              16,
            ),
            nutrients: const Nutrients(),
            status: AnalysisStatus.analyzing,
            notes: _notes.text.trim(),
          ),
        );
    showDemoMessage(context, '已加入内存演示记录；未上传图片或发起真实分析');
    context.pushReplacement(AppRoutes.mealDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(demoProvider).aiConsent;
    return AppPage(
      demoLabel: '设计样例 · 演示数据',
      title: '记录这一餐',
      showBack: true,
      footer: _mode == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '示例图片仅供预览，不发起真实分析',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: _saving ? '正在更新演示…' : '提交并分析（演示）',
                  icon: AppIcons.camera,
                  onPressed: _images > 0 && consent && !_saving
                      ? _submit
                      : null,
                ),
              ],
            )
          : null,
      children: [
        AppSegmented(
          labels: const ['个人拍照', '食堂菜单（演示）'],
          selected: _mode,
          equalWidth: true,
          onChanged: (value) => setState(() => _mode = value),
        ),
        if (_mode == 1) ...[
          const InfoBanner(text: '食堂菜单为独立演示。浏览菜单不会创建实际摄入记录。'),
          AppCard(
            child: Column(
              children: [
                const PlateIllustration(size: 140),
                const SizedBox(height: 16),
                const Text(
                  '食堂菜单（演示）',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: '查看食堂菜单',
                  onPressed: () => context.push(AppRoutes.institutionMenu),
                ),
              ],
            ),
          ),
        ] else ...[
          AppCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              onTap: () => context.push(AppRoutes.aiConsent),
              child: Row(
                children: [
                  const Icon(AppIcons.shieldCheck, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consent ? 'AI 营养分析演示已开启' : 'AI 分析演示已关闭',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consent ? '仅用于本餐演示，可在隐私页撤回' : '仍可编辑草稿，提交分析不可用',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          AdaptiveColumns(
            main: [
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '本餐图片',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppBadge(label: '$_images 张示例已选择'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_images > 0) ...[
                          Expanded(
                            flex: 5,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 118),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      8,
                                      8,
                                      6,
                                    ),
                                    child: Column(
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) =>
                                              Center(
                                                child: PlateIllustration(
                                                  size: constraints.maxWidth
                                                      .clamp(0.0, 96.0)
                                                      .toDouble(),
                                                ),
                                              ),
                                        ),
                                        const Text(
                                          '餐盘示意',
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      tooltip: '移除示例图片',
                                      icon: const Icon(
                                        AppIcons.close,
                                        size: 16,
                                      ),
                                      onPressed: () =>
                                          setState(() => _images--),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          flex: 7,
                          child: OutlinedButton(
                            onPressed: _images < 3 ? _selectImage : null,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.canvas,
                              minimumSize: const Size(0, 118),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16,
                              ),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(AppIcons.plus, size: 30),
                                const SizedBox(height: 10),
                                Text(
                                  _images == 0
                                      ? '添加餐盘示例'
                                      : _images == 3
                                      ? '已选满 3 张示例'
                                      : '补充同一餐图片',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '多角度不会重复计量',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      label: const Text('拍照（示例）', textAlign: TextAlign.center),
                      icon: const Icon(AppIcons.camera, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.greenSoft,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _images < 3 ? _selectImage : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      label: const Text('从相册选择', textAlign: TextAlign.center),
                      icon: const Icon(AppIcons.image, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.greenSoft,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _images < 3 ? _selectImage : null,
                    ),
                  ),
                ],
              ),
              if (_hasDraft)
                AppCard(
                  radius: 14,
                  color: AppColors.greenSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: InkWell(
                    onTap: _draft,
                    child: Row(
                      children: [
                        const Icon(AppIcons.history, color: AppColors.primary),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '另有 1 份未提交草稿',
                                style: TextStyle(fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '昨日保存，进入后可继续编辑',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          AppIcons.chevronRight,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            aside: [
              const SectionHeading(title: '这是什么餐？'),
              AppSegmented(
                labels: MealType.values.map((type) => type.label).toList(),
                selected: MealType.values.indexOf(_type),
                equalWidth: true,
                selectedFilled: true,
                onChanged: (index) =>
                    setState(() => _type = MealType.values[index]),
              ),
              const Text(
                '备注（选填）',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '例如：清蒸、少油，或补充菜品名称',
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const InfoBanner(
                text: '采集说明\n尽量拍完整餐盘，光线充足，避免遮挡。\n当前仅可选择最多 3 张本地餐盘示意，不申请设备权限。\n演示记录显示分析中，不会自动生成真实营养。',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
