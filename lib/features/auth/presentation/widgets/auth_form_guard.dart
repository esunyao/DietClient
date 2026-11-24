import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/navigation_manager.dart';

/// 认证表单未保存离开拦截组件，存在未提交输入时弹窗请求确认。
class AuthFormGuard extends ConsumerStatefulWidget {
  const AuthFormGuard({super.key, required this.dirty, required this.child});

  final bool dirty;
  final Widget child;

  @override
  ConsumerState<AuthFormGuard> createState() => _AuthFormGuardState();
}

class _AuthFormGuardState extends ConsumerState<AuthFormGuard> {
  bool _discard = false;
  bool _asking = false;

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || _asking) return;
    _asking = true;
    final discard = await showAppConfirmDialog(
      context,
      title: '放弃未保留的修改？',
      content: '继续编辑会保留当前输入；放弃后不会更新演示资料。',
      confirmLabel: '放弃修改',
      cancelLabel: '继续编辑',
    );
    _asking = false;
    // 先允许再次出栈，再于下一帧调用导航出栈，避免重复触发离开确认框。
    if (discard && mounted) {
      setState(() => _discard = true);
      final navigation = ref.read(navigationManagerProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigation.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.dirty || _discard,
    onPopInvokedWithResult: _onPopInvoked,
    child: widget.child,
  );
}
