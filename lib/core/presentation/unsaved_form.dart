import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// @brief 路由离开确认注册表。
/// @details 供路由替换和系统返回复用，避免侧栏绕过表单保护。
class RouteLeaveRegistry {
  final Map<Object, Future<bool> Function()> _checks = {};
  final Map<Object, bool Function()> _busy = {};
  bool get busy => _busy.values.any((check) => check());
  void register(
    Object owner,
    Future<bool> Function() check, {
    required bool Function() busy,
  }) {
    _checks[owner] = check;
    _busy[owner] = busy;
  }

  void remove(Object owner) {
    _checks.remove(owner);
    _busy.remove(owner);
  }

  /// @brief 依次执行所有已注册的离开确认检查。
  /// @details 从最近注册的检查开始逆序确认，任一检查拒绝即停止。
  /// @return 全部检查均允许离开时返回 true，否则返回 false。
  Future<bool> confirm() async {
    for (final owner in _checks.keys.toList().reversed) {
      final check = _checks[owner];
      if (check != null && !await check()) return false;
    }
    return true;
  }
}

final routeLeaveRegistryProvider = Provider((ref) => RouteLeaveRegistry());

/// @brief 返回上一页或在无返回栈时跳转至回退路径。
/// @details 优先弹出路由；GoRouter 无返回栈时转往指定位置，非 GoRouter 仅尝试弹出。
/// @param context 当前构建上下文。
/// @param fallbackLocation 无可弹出路由时的回退路径。
void returnOrGo(BuildContext context, String fallbackLocation) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallbackLocation);
    }
  } else if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

/// @brief 未保存表单离开保护组件。
/// @details 将表单注册到共享离开检查，并通过 PopScope 保护系统返回；保存中拒绝离开，存在未保存修改时由用户确认是否放弃。
class UnsavedForm extends ConsumerStatefulWidget {
  const UnsavedForm({
    super.key,
    required this.dirty,
    required this.child,
    this.busy = false,
    this.fallbackLocation = AppRoutes.home,
  });
  final bool dirty;
  final bool busy;
  final String fallbackLocation;
  final Widget child;
  @override
  ConsumerState<UnsavedForm> createState() => _UnsavedFormState();
}

class _UnsavedFormState extends ConsumerState<UnsavedForm> {
  late final RouteLeaveRegistry _registry;
  bool _discard = false;
  bool _asking = false;
  @override
  void initState() {
    super.initState();
    _registry = ref.read(routeLeaveRegistryProvider);
    _registry.register(
      this,
      _confirm,
      busy: () =>
          mounted && widget.busy && ModalRoute.of(context)?.isCurrent != false,
    );
  }

  /// @brief 执行当前表单的离开确认逻辑。
  /// @details 非当前路由不拦截以避免重复弹窗；对话框结束后再次检查挂载和保存状态。
  /// @return 允许离开页面时返回 true，否则返回 false。
  Future<bool> _confirm() async {
    if (!mounted) return true;
    if (_asking) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return true;
    if (widget.busy) return false;
    if (!widget.dirty || _discard) return true;
    _asking = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放弃未保留的修改？'),
          content: const Text('继续编辑会保留当前输入；放弃后将丢弃未保存的修改。'),
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
      if (!mounted || widget.busy) return false;
      if (discard == true) setState(() => _discard = true);
      return discard == true;
    } finally {
      _asking = false;
    }
  }

  /// @brief 释放组件状态并从离开检查注册表移除当前表单。
  @override
  void dispose() {
    _registry.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.busy && (!widget.dirty || _discard),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || !await _confirm() || !mounted) return;
      // 确认后在下一帧执行返回或无栈回退，并再次检查页面是否仍挂载。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) returnOrGo(context, widget.fallbackLocation);
      });
    },
    child: widget.child,
  );
}
