import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';

/// 启动会话恢复页；恢复完成前阻止构建业务页，网络失败时保留本机恢复凭据供重试。
class SessionRestoreScreen extends ConsumerWidget {
  const SessionRestoreScreen({super.key});

  Future<void> _retry(WidgetRef ref) async {
    final controller = ref.read(sessionProvider.notifier);
    try {
      if (ref.read(sessionProvider) != null) {
        await controller.ensureFreshAccessToken(force: true);
      } else {
        await controller.restore();
      }
    } catch (_) {
      // 由会话控制器负责切换 retryRequired 与安全提示文案。
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed =
        ref.watch(sessionStatusProvider) == SessionStatus.retryRequired;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(title: failed ? '暂时无法恢复登录' : '正在恢复登录'),
                    const SizedBox(height: 16),
                    if (!failed) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      failed ? '请检查网络后重试，或清除本机登录信息重新登录。' : '正在验证已保存的登录信息，请稍候。',
                    ),
                    if (failed) ...[
                      const SizedBox(height: 20),
                      AppButton(label: '重试', onPressed: () => _retry(ref)),
                      const SizedBox(height: 8),
                      AppButton(
                        label: '重新登录',
                        secondary: true,
                        onPressed: () =>
                            ref.read(sessionProvider.notifier).clear(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
