import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// 供路由替换和系统返回复用，避免侧栏绕过表单保护。
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

  Future<bool> confirm() async {
    for (final owner in _checks.keys.toList().reversed) {
      final check = _checks[owner];
      if (check != null && !await check()) return false;
    }
    return true;
  }
}

final routeLeaveRegistryProvider = Provider((ref) => RouteLeaveRegistry());

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) returnOrGo(context, widget.fallbackLocation);
      });
    },
    child: widget.child,
  );
}
