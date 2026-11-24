import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/nutrition/application/nutrition_providers.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/presentation/unsaved_form.dart';
import '../../../../core/privacy/ai_consent.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/capture_controller.dart';

/// 原生真实餐食采集与识别提交页，组合策略、草稿、AI 授权与图片上传流程。
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

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(bool retry) async {
    final epoch = ref.read(sessionEpochProvider);
    final notesText = _notes.text.trim();
    final result = await ref
        .read(captureFlowProvider.notifier)
        .submit(
          mealType: kMealTypeKeys[_type],
          notes: notesText.isEmpty ? null : notesText,
          retry: retry,
        );
    if (!mounted || epoch != ref.read(sessionEpochProvider) || result == null) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent == false) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已受理，正在排队分析')));
    ref
        .read(navigationManagerProvider)
        .scheduleSafeReplace(
          context,
          AppRoutes.mealDetail(result.meal.mealId),
          isValid: () => ref.read(sessionEpochProvider) == epoch,
        );
  }

  Future<void> _delete(String id) async {
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除这份草稿？',
      content: '草稿及其图片将被移除。',
      confirmLabel: '删除',
    );
    if (!mounted || !confirmed || ref.read(sessionEpochProvider) != epoch) {
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
      final proceed = await showAppConfirmDialog(
        context,
        title: '切换到这份草稿？',
        content: '当前未上传的图片与备注只在本页保留，切换后会清除；已上传的图片留在服务端草稿中。',
        confirmLabel: '切换草稿',
      );
      if (!mounted || epoch != ref.read(sessionEpochProvider) || !proceed) {
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
    // 备注和餐别属于页面本地状态，换号时与采集控制器状态一同重置。
    ref.listen(sessionEpochProvider, (_, _) {
      _notes.clear();
      setState(() => _type = 1);
    });
    final flow = ref.watch(captureFlowProvider);
    final controller = ref.read(captureFlowProvider.notifier);
    final policy = ref.watch(capturePolicyProvider);
    final drafts = ref.watch(draftsProvider);
    final consent = ref.watch(aiNutritionConsentProvider);
    final navigation = ref.read(navigationManagerProvider);
    final nutrition = ref.read(nutritionManagerProvider);
    final session = flow.session;

    return UnsavedForm(
      dirty: flow.isDirtyFor(_notes.text),
      busy: flow.busy,
      child: AppPage(
        title: '记录这一餐',
        demoLabel: null,
        showBack: true,
        footer: _CaptureFooter(
          busy: flow.busy,
          isFailed: flow.isFailed,
          canSubmit: flow.canSubmit,
          onSubmit: () => _submit(flow.isFailed),
        ),
        children: [
          if (flow.error != null) InfoBanner(text: flow.error!),
          _ConsentStatusCard(
            consent: consent,
            busy: flow.busy,
            onOpenConsent: () => navigation.openAiConsent(context),
            onRetry: () => ref.read(aiConsentManagerProvider).refreshRecords(),
          ),
          _CapturePolicyBanner(
            policy: policy,
            onRetry: nutrition.refreshPolicy,
          ),
          if (session == null)
            _NewDraftCard(
              busy: flow.busy,
              policyReady: policy.hasValue,
              onCreate: controller.create,
            ),
          if (session != null) ...[
            _ActiveDraftCard(
              flow: flow,
              session: session,
              imageCount: controller.imageCount,
              policyReady: policy.hasValue,
              controller: controller,
              onDelete: () => _delete(session.captureSessionId),
            ),
            const SectionHeading(title: '这是什么餐？'),
            AppSegmented(
              labels: kMealTypeDisplayLabels,
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
          _ServerDraftsCard(
            drafts: drafts,
            busy: flow.busy,
            onOpen: _open,
            onDelete: _delete,
            onRefresh: nutrition.refreshDrafts,
          ),
          const InfoBanner(
            text: '选择或恢复的图片先进入待确认区；点击上传后才会上传。离开页面保留服务端草稿，本地待上传图片不会持久保存。',
          ),
        ],
      ),
    );
  }
}

class _CaptureFooter extends StatelessWidget {
  const _CaptureFooter({
    required this.busy,
    required this.isFailed,
    required this.canSubmit,
    required this.onSubmit,
  });

  final bool busy;
  final bool isFailed;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
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
        label: busy
            ? '正在处理…'
            : isFailed
            ? '重新发起分析'
            : '提交并分析',
        onPressed: canSubmit ? onSubmit : null,
      ),
    ],
  );
}

class _ConsentStatusCard extends StatelessWidget {
  const _ConsentStatusCard({
    required this.consent,
    required this.busy,
    required this.onOpenConsent,
    required this.onRetry,
  });

  final AsyncValue<bool> consent;
  final bool busy;
  final VoidCallback onOpenConsent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    radius: 14,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.shieldCheck, color: AppColors.primary),
          title: Text(
            consent.when(
              data: (yes) => yes ? 'AI 营养分析已授权' : '请先授权 AI 营养分析',
              loading: () => '正在核实 AI 授权',
              error: (_, _) => 'AI 授权读取失败',
            ),
          ),
          subtitle: const Text('每次提交或重试都会重新核实授权'),
          trailing: const Icon(AppIcons.chevronRight),
          onTap: busy ? null : onOpenConsent,
        ),
        if (consent.hasError)
          TextButton(onPressed: onRetry, child: const Text('重试读取授权')),
      ],
    ),
  );
}

class _CapturePolicyBanner extends StatelessWidget {
  const _CapturePolicyBanner({required this.policy, required this.onRetry});

  final AsyncValue<CapturePolicy> policy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => policy.when(
    data: (value) => InfoBanner(
      text:
          '每餐最多 ${value.maxImageCount} 张，每张不超过 ${(value.maxFileSizeBytes / 1024 / 1024).toStringAsFixed(0)} MB；支持 ${value.allowedContentTypes.map((v) => v.split('/').last).join(' / ')}。保留完整照片，不裁剪餐盘。',
    ),
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => AppCard(
      child: Column(
        children: [
          const Text('采集策略读取失败'),
          TextButton(onPressed: onRetry, child: const Text('重试读取策略')),
        ],
      ),
    ),
  );
}

class _NewDraftCard extends StatelessWidget {
  const _NewDraftCard({
    required this.busy,
    required this.policyReady,
    required this.onCreate,
  });

  final bool busy;
  final bool policyReady;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '新建本餐草稿',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: busy ? '正在新建…' : '新建草稿',
          onPressed: !busy && policyReady ? onCreate : null,
        ),
      ],
    ),
  );
}

class _ActiveDraftCard extends StatelessWidget {
  const _ActiveDraftCard({
    required this.flow,
    required this.session,
    required this.imageCount,
    required this.policyReady,
    required this.controller,
    required this.onDelete,
  });

  final CaptureFlowState flow;
  final CaptureSession session;
  final int imageCount;
  final bool policyReady;
  final CaptureController controller;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '本餐图片 · $imageCount 张',
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
          '状态：${captureStatusLabel(session.status)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (flow.isExpired) const InfoBanner(text: '草稿已过期，请删除后新建'),
        for (final image in flow.visibleServerImages)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (image.previewUrl != null && image.status == 'confirmed')
                  Image.network(
                    image.previewUrl!,
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => TextButton(
                      onPressed: flow.busy ? null : controller.refreshSession,
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
                      onPressed: !flow.busy && flow.isEditable
                          ? () => controller.removeImage(image.imageId)
                          : null,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        for (final pending in flow.visiblePendingImages)
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
                if (flow.busy) LinearProgressIndicator(value: pending.progress),
              ],
            ),
          ),
        if (flow.hasUnconfirmedPending) ...[
          const SizedBox(height: 10),
          AppButton(
            label: '上传所选图片 / 重试未完成步骤',
            onPressed: !flow.busy && flow.isEditable ? controller.upload : null,
          ),
        ],
        if (flow.busy)
          TextButton(onPressed: controller.cancel, child: const Text('取消上传')),
        if (flow.isEditable) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: !flow.busy && policyReady
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
                  onPressed: !flow.busy && policyReady
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
          onPressed: flow.busy ? null : onDelete,
          child: const Text('删除当前草稿'),
        ),
      ],
    ),
  );
}

class _ServerDraftsCard extends StatelessWidget {
  const _ServerDraftsCard({
    required this.drafts,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
    required this.onRefresh,
  });

  final AsyncValue<CaptureDraftPage> drafts;
  final bool busy;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => drafts.when(
    data: (page) => AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (page.items.isEmpty) const Text('暂无未提交草稿'),
          for (final draft in page.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${draft.confirmedImageCount} 张已确认 · ${captureStatusLabel(draft.status)}',
              ),
              subtitle: Text(
                '更新于 ${draft.updatedAt.toLocal().toString().split('.').first}',
              ),
              trailing: IconButton(
                tooltip: '删除草稿',
                onPressed: busy ? null : () => onDelete(draft.captureSessionId),
                icon: const Icon(Icons.delete_outline),
              ),
              onTap: busy ? null : () => onOpen(draft.captureSessionId),
            ),
          TextButton(onPressed: onRefresh, child: const Text('刷新草稿')),
        ],
      ),
    ),
    loading: () => const LinearProgressIndicator(),
    error: (_, _) => AppCard(
      child: Column(
        children: [
          const Text('草稿列表读取失败'),
          TextButton(onPressed: onRefresh, child: const Text('重试读取草稿')),
        ],
      ),
    ),
  );
}
