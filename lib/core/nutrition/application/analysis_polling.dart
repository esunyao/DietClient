import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../session/session_controller.dart';
import 'nutrition_providers.dart';

bool analysisPending(String status) =>
    const ['pending', 'queued', 'analysing', 'analyzing'].contains(status);

/// One clock refreshes shared queries once for all visible consumers.
class AnalysisPolling {
  AnalysisPolling(this.refresh);
  final void Function() refresh;
  final Map<Object, ({bool active, void Function() timeout})> _leases = {};
  final Map<Object, Duration> _elapsed = {};
  final Map<Object, ({Object group, void Function() refresh})> _actions = {};
  Timer? _timer;
  void update(
    Object key, {
    required bool pending,
    required bool active,
    required void Function() timeout,
    Object? group,
    void Function()? onRefresh,
  }) {
    if (!pending) {
      _leases.remove(key);
      _elapsed.remove(key);
      _actions.remove(key);
    } else {
      _leases[key] = (active: active, timeout: timeout);
      _elapsed.putIfAbsent(key, () => Duration.zero);
      if (onRefresh != null) {
        _actions[key] = (group: group ?? key, refresh: onRefresh);
      }
    }
    _sync();
  }

  void remove(Object key) {
    _leases.remove(key);
    _elapsed.remove(key);
    _actions.remove(key);
    _sync();
  }

  bool expired(Object key) =>
      (_elapsed[key] ?? Duration.zero) >= const Duration(minutes: 2);
  void restart(Object key) {
    _elapsed[key] = Duration.zero;
    _sync();
  }

  void _sync() {
    final active = _leases.keys.any(
      (key) => _leases[key]!.active && !expired(key),
    );
    if (!active) {
      _timer?.cancel();
      _timer = null;
    }
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        final keys = _leases.keys
            .where((key) => _leases[key]!.active && !expired(key))
            .toList();
        final actions = <Object, void Function()>{};
        var defaultRefresh = false;
        for (final key in keys) {
          final action = _actions[key];
          if (action == null) {
            defaultRefresh = true;
          } else {
            actions[action.group] = action.refresh;
          }
        }
        if (defaultRefresh) refresh();
        for (final action in actions.values) {
          action();
        }
        for (final key in keys) {
          _elapsed[key] = _elapsed[key]! + const Duration(seconds: 3);
          if (expired(key)) _leases[key]?.timeout();
        }
        _sync();
      });
    }
  }

  void dispose() {
    _timer?.cancel();
    _leases.clear();
    _elapsed.clear();
    _actions.clear();
  }
}

final analysisPollingProvider = Provider<AnalysisPolling>((ref) {
  ref.watch(sessionEpochProvider);
  final controller = AnalysisPolling(() {});
  ref.onDispose(controller.dispose);
  return controller;
});

class NutritionPolling extends ConsumerStatefulWidget {
  const NutritionPolling({
    super.key,
    required this.pending,
    required this.child,
    required this.onRefresh,
    this.refreshKey,
  });
  final bool pending;
  final Widget child;
  final VoidCallback onRefresh;
  final Object? refreshKey;
  @override
  ConsumerState<NutritionPolling> createState() => _NutritionPollingState();
}

class _NutritionPollingState extends ConsumerState<NutritionPolling>
    with WidgetsBindingObserver {
  final _lease = Object();
  AnalysisPolling? _controller;
  GoRouter? _router;
  String? _path;
  bool _foreground = true;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_visibility);
      _router = router;
      _router?.routerDelegate.addListener(_visibility);
    }
    _path ??= router?.routeInformationProvider.value.uri.path;
    _schedule();
  }

  @override
  void didUpdateWidget(NutritionPolling oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _controller?.remove(_lease);
      _expired = false;
    }
    if (!widget.pending) _expired = false;
    if (oldWidget.pending && !widget.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshNutrition(ref);
      });
    }
    _schedule();
  }

  void _schedule() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _visibility();
  });
  void _visibility() {
    if (!mounted) return;
    final controller = ref.read(analysisPollingProvider);
    if (_controller != controller) {
      _controller?.remove(_lease);
      _controller = controller;
    }
    final routeVisible =
        _router == null ||
        _router!.routeInformationProvider.value.uri.path == _path;
    controller.update(
      _lease,
      pending: widget.pending,
      group: widget.refreshKey,
      onRefresh: widget.onRefresh,
      active:
          _foreground &&
          routeVisible &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      timeout: () {
        if (mounted) setState(() => _expired = true);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _visibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_visibility);
    _controller?.remove(_lease);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionEpochProvider);
    _schedule();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expired && widget.pending)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () {
                _controller?.restart(_lease);
                setState(() => _expired = false);
                widget.onRefresh();
              },
              child: const Text('分析仍未结束，点击手动刷新'),
            ),
          ),
        widget.child,
      ],
    );
  }
}
