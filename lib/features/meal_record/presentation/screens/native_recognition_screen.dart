import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/unsaved_form.dart';
import '../../../../core/privacy/ai_consent.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/capture_controller.dart';

class NativeRecognitionScreen extends ConsumerStatefulWidget {
  const NativeRecognitionScreen({super.key});
  @override
  ConsumerState<NativeRecognitionScreen> createState() =>
      _NativeRecognitionScreenState();
}

class _NativeRecognitionScreenState
    extends ConsumerState<NativeRecognitionScreen> {
  final _notes = TextEditingController();
  int _type = 1;
  static const _types = ['breakfast', 'lunch', 'dinner', 'snack', 'other'];
  static const _labels = ['早餐', '午餐', '晚餐', '加餐', '其他'];
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(bool retry) async {
    final epoch = ref.read(sessionEpochProvider);
    final result = await ref
        .read(captureFlowProvider.notifier)
        .submit(
          mealType: _types[_type],
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          retry: retry,
        );
    if (!mounted || epoch != ref.read(sessionEpochProvider) || result == null) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent == false) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已受理，正在排队分析')));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          epoch == ref.read(sessionEpochProvider) &&
          ModalRoute.of(context)?.isCurrent != false) {
        context.pushReplacement(AppRoutes.mealDetail(result.meal.mealId));
      }
    });
  }

  Future<void> _delete(String id) async {
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这份草稿？'),
        content: const Text('草稿及其图片将被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(sessionEpochProvider) != epoch) {
      return;
    }
    await ref.read(captureFlowProvider.notifier).deleteDraft(id);
  }

  Future<void> _open(String id) async {
    final controller = ref.read(captureFlowProvider.notifier);
    final previous = ref.read(captureFlowProvider);
    if (previous.session?.captureSessionId == id) {
      await controller.refreshSession();
      return;
    }
    final epoch = ref.read(sessionEpochProvider);
    if (previous.pending.isNotEmpty || _notes.text.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('切换到这份草稿？'),
          content: const Text('当前未上传的图片与备注只在本页保留，切换后会清除；已上传的图片留在服务端草稿中。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('切换草稿'),
            ),
          ],
        ),
      );
      if (!mounted ||
          epoch != ref.read(sessionEpochProvider) ||
          proceed != true) {
        return;
      }
    }
    await controller.open(id);
    if (!mounted || epoch != ref.read(sessionEpochProvider)) return;
    if (ref.read(captureFlowProvider).session?.captureSessionId == id) {
      _notes.clear();
      setState(() => _type = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionEpochProvider, (_, _) {
      _notes.clear();
      setState(() => _type = 1);
    });
    final flow = ref.watch(captureFlowProvider);
    final controller = ref.read(captureFlowProvider.notifier);
    final policy = ref.watch(capturePolicyProvider);
    final drafts = ref.watch(draftsProvider);
    final consent = ref.watch(aiNutritionConsentProvider);
    final session = flow.session;
    final failed = session?.status == 'failed';
    final editable =
        session != null &&
        ['created', 'uploading'].contains(session.status) &&
        session.expiresAt.isAfter(DateTime.now());
    final confirmedImages =
        session?.images
            .where((image) => image.status == 'confirmed')
            .toList() ??
        <CaptureImage>[];
    final canSubmit =
        !flow.busy &&
        (failed || (editable && confirmedImages.isNotEmpty)) &&
        !flow.pending.any(
          (p) =>
              p.confirmed == null &&
              !confirmedImages.any((i) => i.imageId == p.signed?.imageId),
        );
    return UnsavedForm(
      dirty:
          session != null &&
          const ['created', 'uploading', 'failed'].contains(session.status) &&
          (_notes.text.isNotEmpty ||
              flow.pending.any((p) => p.confirmed == null)),
      busy: flow.busy,
      child: AppPage(
        title: '记录这一餐',
        demoLabel: null,
        showBack: true,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '提交后异步分析，可在餐食详情查看进度',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: flow.busy
                  ? '正在处理…'
                  : failed
                  ? '重新发起分析'
                  : '提交并分析',
              onPressed: canSubmit ? () => _submit(failed) : null,
            ),
          ],
        ),
        children: [
          if (flow.error != null) InfoBanner(text: flow.error!),
          AppCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    AppIcons.shieldCheck,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    consent.when(
                      data: (yes) => yes ? 'AI 营养分析已授权' : '请先授权 AI 营养分析',
                      loading: () => '正在核实 AI 授权',
                      error: (_, _) => 'AI 授权读取失败',
                    ),
                  ),
                  subtitle: const Text('每次提交或重试都会重新核实授权'),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: flow.busy
                      ? null
                      : () => context.push(AppRoutes.aiConsent),
                ),
                if (consent.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(consentRecordsProvider),
                    child: const Text('重试读取授权'),
                  ),
              ],
            ),
          ),
          policy.when(
            data: (value) => InfoBanner(
              text:
                  '每餐最多 ${value.maxImageCount} 张，每张不超过 ${(value.maxFileSizeBytes / 1024 / 1024).toStringAsFixed(0)} MB；支持 ${value.allowedContentTypes.map((v) => v.split('/').last).join(' / ')}。保留完整照片，不裁剪餐盘。',
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => AppCard(
              child: Column(
                children: [
                  const Text('采集策略读取失败'),
                  TextButton(
                    onPressed: () => ref.invalidate(capturePolicyProvider),
                    child: const Text('重试读取策略'),
                  ),
                ],
              ),
            ),
          ),
          if (session == null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '新建本餐草稿',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: flow.busy ? '正在新建…' : '新建草稿',
                    onPressed: !flow.busy && policy.hasValue
                        ? controller.create
                        : null,
                  ),
                ],
              ),
            ),
          if (session != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '本餐图片 · ${controller.imageCount} 张',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: flow.busy ? null : controller.refreshSession,
                        child: const Text('刷新图片'),
                      ),
                    ],
                  ),
                  Text(
                    '状态：${_statusLabel(session.status)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (session.expiresAt.isBefore(DateTime.now()))
                    const InfoBanner(text: '草稿已过期，请删除后新建'),
                  for (final image in session.images.where(
                    (image) => image.status != 'deleted',
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (image.previewUrl != null &&
                              image.status == 'confirmed')
                            Image.network(
                              image.previewUrl!,
                              height: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => TextButton(
                                onPressed: flow.busy
                                    ? null
                                    : controller.refreshSession,
                                child: const Text('图片链接已失效，点击刷新'),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  image.status == 'confirmed'
                                      ? '图片已确认'
                                      : '图片尚未确认；可移除后重新选择',
                                ),
                              ),
                              IconButton(
                                tooltip: '移除图片',
                                onPressed: !flow.busy && editable
                                    ? () =>
                                          controller.removeImage(image.imageId)
                                    : null,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  for (final pending in flow.pending.where(
                    (p) => !session.images.any(
                      (i) =>
                          i.status != 'deleted' &&
                          i.imageId == p.signed?.imageId,
                    ),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.memory(
                            pending.image.bytes,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                          Row(
                            children: [
                              Expanded(child: Text(pending.stage)),
                              IconButton(
                                tooltip: '移除待上传图片',
                                onPressed: flow.busy
                                    ? null
                                    : () => controller.removePending(pending),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                          if (flow.busy)
                            LinearProgressIndicator(value: pending.progress),
                        ],
                      ),
                    ),
                  if (flow.pending.any((p) => p.confirmed == null)) ...[
                    const SizedBox(height: 10),
                    AppButton(
                      label: '上传所选图片 / 重试未完成步骤',
                      onPressed: !flow.busy && editable
                          ? controller.upload
                          : null,
                    ),
                  ],
                  if (flow.busy)
                    TextButton(
                      onPressed: controller.cancel,
                      child: const Text('取消上传'),
                    ),
                  if (editable) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (defaultTargetPlatform ==
                            TargetPlatform.android) ...[
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: !flow.busy && policy.hasValue
                                  ? () => controller.pick(ImageSource.camera)
                                  : null,
                              icon: const Icon(AppIcons.camera, size: 18),
                              label: const Text('拍照'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: !flow.busy && policy.hasValue
                                ? () => controller.pick(ImageSource.gallery)
                                : null,
                            icon: const Icon(AppIcons.image, size: 18),
                            label: Text(
                              defaultTargetPlatform == TargetPlatform.windows
                                  ? '选择图片'
                                  : '从相册选择',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  TextButton(
                    onPressed: flow.busy
                        ? null
                        : () => _delete(session.captureSessionId),
                    child: const Text('删除当前草稿'),
                  ),
                ],
              ),
            ),
            const SectionHeading(title: '这是什么餐？'),
            AppSegmented(
              labels: _labels,
              selected: _type,
              equalWidth: true,
              selectedFilled: true,
              onChanged: (index) {
                if (!flow.busy) setState(() => _type = index);
              },
            ),
            TextField(
              controller: _notes,
              onChanged: (_) => setState(() {}),
              enabled: !flow.busy,
              minLines: 2,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                hintText: '例如：清蒸、少油，或补充菜品名称',
              ),
            ),
          ],
          const SectionHeading(title: '服务端草稿'),
          drafts.when(
            data: (page) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (page.items.isEmpty) const Text('暂无未提交草稿'),
                  for (final draft in page.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${draft.confirmedImageCount} 张已确认 · ${_statusLabel(draft.status)}',
                      ),
                      subtitle: Text(
                        '更新于 ${draft.updatedAt.toLocal().toString().split('.').first}',
                      ),
                      trailing: IconButton(
                        tooltip: '删除草稿',
                        onPressed: flow.busy
                            ? null
                            : () => _delete(draft.captureSessionId),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      onTap: flow.busy
                          ? null
                          : () => _open(draft.captureSessionId),
                    ),
                  TextButton(
                    onPressed: () => ref.invalidate(draftsProvider),
                    child: const Text('刷新草稿'),
                  ),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => AppCard(
              child: Column(
                children: [
                  const Text('草稿列表读取失败'),
                  TextButton(
                    onPressed: () => ref.invalidate(draftsProvider),
                    child: const Text('重试读取草稿'),
                  ),
                ],
              ),
            ),
          ),
          const InfoBanner(
            text: '选择或恢复的图片先进入待确认区；点击上传后才会上传。离开页面保留服务端草稿，本地待上传图片不会持久保存。',
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'created' => '待添加图片',
    'uploading' => '正在准备图片',
    'failed' => '分析失败，可重新发起',
    'submitted' || 'queued' || 'analyzing' => '已受理分析',
    'completed' => '分析完成',
    _ => status,
  };
}
