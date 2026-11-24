import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_controller.dart';
import '../../application/profile_state.dart';
import '../../data/profile_api.dart';
import '../widgets/remote_state.dart';

/// 真实 AI 营养分析同意管理页面，支持查看授权记录并在确认后追加授权或撤回。
class RealConsentScreen extends ConsumerStatefulWidget {
  const RealConsentScreen({super.key});

  @override
  ConsumerState<RealConsentScreen> createState() => _RealConsentState();
}

class _RealConsentState extends ConsumerState<RealConsentScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _save(bool granted) async {
    final epoch = ref.read(sessionEpochProvider);
    final confirmed = await showAppConfirmDialog(
      context,
      title: granted ? '同意 AI 营养分析使用健康资料？' : '撤回 AI 营养分析同意？',
      content: '将追加一条政策版本 1.0 的同意记录。基础资料、测量、目标、过敏、疾病与饮食限制用于营养分析；历史记录会保留。',
      confirmLabel: granted ? '同意' : '撤回',
    );
    if (!confirmed || !mounted) return;
    if (epoch != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请重新确认。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileManagerProvider)
          .submitAiConsent(
            granted: granted,
            source: kIsWeb ? 'web' : 'mobile',
            epoch: epoch,
          );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiFailure
              ? error.message
              : '保存未确认，请刷新授权状态后重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    demoLabel: null,
    title: 'AI 数据与隐私',
    showBack: true,
    subtitle: 'AI 营养分析用途与同意记录',
    children: [
      if (_error != null) InfoBanner(text: _error!),
      RemoteState(
        value: ref.watch(consentsProvider),
        retry: () => ref.read(profileManagerProvider).refreshConsents(),
        builder: (records) {
          final status = consentStatus(records);
          final latest = latestConsent(records);
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(AppIcons.shield, color: AppColors.primary, size: 32),
                const SizedBox(height: 16),
                AppBadge(label: status),
                const SizedBox(height: 16),
                const Text(
                  '用于分析基础资料、最近身体测量、健康目标、过敏、疾病与饮食限制。填写资料不等于授权。你可以随时撤回，撤回会保留历史同意记录。',
                ),
                const SizedBox(height: 16),
                const Text('当前政策版本：1.0'),
                if (latest != null)
                  Text(
                    '最近记录：${latest['recordedAt']}\n记录版本：${latest['policyVersion']}',
                  ),
                const SizedBox(height: 20),
                AppButton(
                  label: _saving
                      ? '保存中…'
                      : status == '已授权'
                      ? '撤回同意'
                      : '同意此用途',
                  onPressed: _saving ? null : () => _save(status != '已授权'),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
