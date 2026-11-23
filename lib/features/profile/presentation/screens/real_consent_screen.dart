import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diet_ui/diet_ui.dart';

import '../../application/profile_state.dart';
import '../../data/profile_api.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/remote_state.dart';

/// @brief 真实 AI 营养分析同意管理页面。
/// @details 读取真实同意记录并在用户确认后追加授权或撤回记录；加载失败时支持重新查询。
class RealConsentScreen extends ConsumerStatefulWidget {
  const RealConsentScreen({super.key});
  @override
  ConsumerState<RealConsentScreen> createState() => _RealConsentState();
}

class _RealConsentState extends ConsumerState<RealConsentScreen> {
  bool _saving = false;
  String? _error;

  /// @brief 弹出确认对话框并提交新的 AI 同意或撤回记录。
  /// @details 弹窗前记录登录代次，确认后拒绝跨账户提交；写入成功仅刷新仍匹配的 API 查询。
  /// @param granted 目标授权状态，true 表示同意，false 表示撤回。
  Future<void> _save(bool granted) async {
    final session = ref.read(sessionEpochProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(granted ? '同意 AI 营养分析使用健康资料？' : '撤回 AI 营养分析同意？'),
        content: const Text(
          '将追加一条政策版本 1.0 的同意记录。基础资料、测量、目标、过敏、疾病与饮食限制用于营养分析；历史记录会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(granted ? '同意' : '撤回'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (session != ref.read(sessionEpochProvider)) {
      setState(() => _error = '账户已切换，请重新确认。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(profileApiProvider);
      if (api == null) throw StateError('会话不可用');
      await api.consent(granted, kIsWeb ? 'web' : 'mobile');
      if (mounted && identical(api, ref.read(profileApiProvider))) {
        ref.invalidate(consentsProvider);
      }
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
        retry: () => ref.invalidate(consentsProvider),
        // 状态和最近记录由共享同意规则计算；本页面据状态决定下一次追加的操作。
        builder: (records) {
          final status = consentStatus(records),
              latest = latestConsent(records);
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
