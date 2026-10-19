import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diet_ui/diet_ui.dart';
import 'package:diet_client/core/presentation/app_routes.dart';
import 'package:diet_client/demo/demo_store.dart';

class RecognitionScreen extends ConsumerStatefulWidget {
  const RecognitionScreen({super.key});
  @override
  ConsumerState<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends ConsumerState<RecognitionScreen> {
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
      title: '记录这一餐',
      showBack: true,
      footer: _mode == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '示例图片用于预览，不发起真实分析',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: _saving ? '正在更新演示…' : '提交并分析（演示）',
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
          InfoBanner(
            text: consent
                ? 'AI 营养分析授权 · 演示状态已开启\n仅用于本餐分析，可在隐私页撤回。'
                : 'AI 分析演示开关已关闭。仍可编辑当前草稿，提交分析不可用。',
            icon: Icons.verified_user_outlined,
          ),
          if (!consent)
            AppButton(
              label: '查看 AI 数据与隐私',
              secondary: true,
              onPressed: () => context.push(AppRoutes.aiConsent),
            ),
          AdaptiveColumns(
            main: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(title: '本餐图片', detail: '$_images 张示例已选择'),
                    const SizedBox(height: 20),
                    if (_images > 0) ...[
                      const Center(child: PlateIllustration(size: 175)),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          '餐盘示意',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _images; i++)
                            InputChip(
                              label: Text('示例图片 ${i + 1}'),
                              onDeleted: () => setState(() => _images--),
                            ),
                        ],
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '尚未选择图片，请添加餐盘示例。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '补充同一餐图片',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      '多角度不会重复计量',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppButton(
                          label: '拍照（示例）',
                          secondary: true,
                          icon: Icons.camera_alt_outlined,
                          onPressed: _images < 3 ? _selectImage : null,
                        ),
                        AppButton(
                          label: '从相册选择（示例）',
                          secondary: true,
                          onPressed: _images < 3 ? _selectImage : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_hasDraft)
                AppCard(
                  child: AppListRow(
                    title: '另有 1 份未提交草稿',
                    subtitle: '昨日保存，进入后可继续编辑',
                    leading: const Icon(Icons.drafts_outlined),
                    onTap: _draft,
                  ),
                ),
            ],
            aside: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(title: '这是什么餐？'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: MealType.values
                          .map(
                            (type) => ChoiceChip(
                              label: Text(type.label),
                              selected: _type == type,
                              onSelected: (_) => setState(() => _type = type),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '备注（选填）',
                        hintText: '例如：清蒸、少油，或补充菜品名称',
                      ),
                    ),
                  ],
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
