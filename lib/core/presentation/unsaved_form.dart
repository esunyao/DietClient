import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// 路由离开确认注册表，供路由替换与系统返回共同拦截未保存离开。
class RouteLeaveRegistry {
  final Map<Object, Future<bool> Function()> _checks = {};
  final Map<Object, bool Function()> _busy = {};

  /// 当前是否存在正在保存且不可离开的激活表单。
  bool get busy => _busy.values.any((check) => check());

  /// 注册表单的离开确认回调与忙碌判定回调。
  void register(
    Object owner,
    Future<bool> Function() check, {
    required bool Function() busy,
  }) {
    _checks[owner] = check;
    _busy[owner] = busy;
  }

  /// 注销指定表单的离开检查与忙碌状态。
  void remove(Object owner) {
    _checks.remove(owner);
    _busy.remove(owner);
  }

  /// 按最近注册顺序逆序执行离开确认；任一检查拒绝即中止并返回 `false`。
  Future<bool> confirm() async {
    for (final owner in _checks.keys.toList().reversed) {
      final check = _checks[owner];
      if (check != null && !await check()) return false;
    }
    return true;
  }
}

/// 全局路由离开确认注册表 Provider。
final routeLeaveRegistryProvider = Provider((ref) => RouteLeaveRegistry());

/// 返回上一页；在 GoRouter 无返回栈时回退到 [fallbackLocation]。
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

/// 未保存表单离开保护包裹组件；保存中阻止离开，存在修改时弹窗确认。
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

  Future<bool> _confirm() async {
    if (!mounted) return true;
    if (_asking) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return true;
    if (widget.busy) return false;
    if (!widget.dirty || _discard) return true;
    _asking = true;
    try {
      final discard = await showAppConfirmDialog(
        context,
        title: '放弃未保留的修改？',
        content: '继续编辑会保留当前输入；放弃后将丢弃未保存的修改。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续编辑',
      );
      if (!mounted || widget.busy) return false;
      if (discard) setState(() => _discard = true);
      return discard;
    } finally {
      _asking = false;
    }
  }

  Future<void> _handlePopInvoked(bool didPop, Object? _) async {
    if (didPop || !await _confirm() || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) returnOrGo(context, widget.fallbackLocation);
    });
  }

  @override
  void dispose() {
    _registry.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.busy && (!widget.dirty || _discard),
    onPopInvokedWithResult: _handlePopInvoked,
    child: widget.child,
  );
}
