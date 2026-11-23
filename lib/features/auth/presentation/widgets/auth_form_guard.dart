import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// @brief 认证表单离开拦截保护组件。
/// @details 当表单存在未保留输入时拦截返回操作，并弹窗请求用户确认是否放弃。
class AuthFormGuard extends StatefulWidget {
  const AuthFormGuard({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;
  @override
  State<AuthFormGuard> createState() => _AuthFormGuardState();
}

class _AuthFormGuardState extends State<AuthFormGuard> {
  bool _discard = false;
  bool _asking = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.dirty || _discard,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _asking) return;
      _asking = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放弃未保留的修改？'),
          content: const Text('继续编辑会保留当前输入；放弃后不会更新演示资料。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      _asking = false;
      // 确认后先更新返回许可，再于下一帧重试 pop；避免重复弹出确认框。
      if (discard == true && mounted) {
        setState(() => _discard = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }
    },
    child: widget.child,
  );
}
