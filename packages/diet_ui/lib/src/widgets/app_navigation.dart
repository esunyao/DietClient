import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import 'glass_surface.dart';

/// 导航项定义，包含展示标签与图标。
class AppNavigationDestination {
  const AppNavigationDestination({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// 底部悬浮导航栏的三档收起状态。
enum AppNavigationState { full, compact, mini }

/// 连续三态手机底部悬浮导航栏；横向拖动只做视觉预览，松手后才提交选中项。
class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.collapseProgress = 0,
    this.onExpand,
    this.onInteractionChanged,
    this.glassMode = GlassMode.standard,
    this.reduceTransparency = false,
  });
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double collapseProgress;
  final VoidCallback? onExpand;
  final ValueChanged<bool>? onInteractionChanged;
  final GlassMode glassMode;
  final bool reduceTransparency;

  /// 根据当前 [collapseProgress] 计算对应的显示状态。
  AppNavigationState get displayState => collapseProgress >= 1.99
      ? AppNavigationState.mini
      : collapseProgress >= 1
      ? AppNavigationState.compact
      : AppNavigationState.full;

  /// 按当前文字缩放比例计算完整态底栏高度。
  static double heightFor(
    BuildContext context, {
    required double width,
    required List<AppNavigationDestination> destinations,
  }) => math.max(
    AppLayout.bottomNavigationHeight,
    22 + MediaQuery.textScalerOf(context).scale(11) * 1.2 + 16,
  );
  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    lowerBound: 0,
    upperBound: 2,
    value: widget.collapseProgress,
  );
  double? _dragX;
  late final AnimationController _snap =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
      )..addListener(() {
        if (mounted) setState(() {});
      });
  double? _snapFrom;
  int? _snapIndex;
  bool _dragAllowed = false;
  bool _swallow = false;
  bool _ignoreTap = false;
  int? _primaryPointer;
  double _primaryX = 0;
  bool get _mini => widget.collapseProgress >= 1.99;
  @override
  void didUpdateWidget(AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapseProgress != widget.collapseProgress) {
      _progress.animateTo(
        widget.collapseProgress,
        duration: Duration(
          milliseconds: widget.collapseProgress > _progress.value ? 280 : 220,
        ),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _snap.dispose();
    super.dispose();
  }

  void _finish(double slot, {bool cancel = false}) {
    final x = _dragX;
    final selected = cancel || x == null
        ? widget.selectedIndex
        : (x / slot - .5).round().clamp(0, widget.destinations.length - 1);
    setState(() {
      _dragX = null;
      _dragAllowed = false;
      _snapFrom = x;
      _snapIndex = selected;
    });
    if (x != null && !MediaQuery.disableAnimationsOf(context)) {
      _snap.forward(from: 0);
    }
    if (!cancel && x != null) {
      if (selected != widget.selectedIndex) widget.onSelected(selected);
    }
  }

  void _resetInteractionFlags() {
    Future.microtask(() {
      _swallow = false;
      _ignoreTap = false;
    });
  }

  void _handlePointerEnd(
    PointerEvent event,
    double slot, {
    required bool cancel,
  }) {
    if (event.pointer != _primaryPointer) return;
    if (_dragX != null) _finish(slot, cancel: cancel);
    _primaryPointer = null;
    widget.onInteractionChanged?.call(false);
    _resetInteractionFlags();
  }

  void _handlePointerDown(PointerDownEvent event, double center, double slot) {
    if (_primaryPointer != null) {
      _ignoreTap = true;
      return;
    }
    _ignoreTap = false;
    _primaryPointer = event.pointer;
    _primaryX = event.localPosition.dx;
    widget.onInteractionChanged?.call(true);
    _swallow = _mini;
    _dragAllowed =
        !_swallow && (event.localPosition.dx - center).abs() <= slot / 2;
    if (_swallow) widget.onExpand?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _primaryPointer) return;
    _primaryX = event.localPosition.dx;
    if (_dragX != null) setState(() => _dragX = _primaryX);
  }

  void _handleDragStart(DragStartDetails _) {
    if (!_dragAllowed || _swallow) return;
    _snap.stop();
    setState(() => _dragX = _primaryX);
  }

  void _handleDestinationTap(int index) {
    if (_ignoreTap) return;
    if (_swallow || _mini) {
      widget.onExpand?.call();
      return;
    }
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final p = MediaQuery.disableAnimationsOf(context)
            ? widget.collapseProgress
            : _progress.value;
        final first = p.clamp(0.0, 1.0);
        final narrowing = ((first - .5) * 2).clamp(0.0, 1.0);
        final second = (p - 1).clamp(0.0, 1.0);
        final width = math.min(
          constraints.maxWidth,
          p <= 1 ? 340 - 92 * narrowing : 248 - 64 * second,
        );
        final fullHeight = AppBottomNavigation.heightFor(
          context,
          width: width,
          destinations: widget.destinations,
        );
        final height = p <= 1
            ? fullHeight + (48 - fullHeight) * first
            : 48 - 4 * second;
        final slot = width / widget.destinations.length;
        final snapping = _snap.isAnimating && _snapFrom != null;
        final snapX = snapping
            ? _snapFrom! +
                  (((_snapIndex! + .5) * slot) - _snapFrom!) *
                      Curves.easeOutCubic.transform(_snap.value)
            : null;
        final center = (_dragX ?? snapX ?? (widget.selectedIndex + .5) * slot)
            .clamp(slot / 2, width - slot / 2);
        final active = _dragX != null;
        return SizedBox(
          width: width,
          height: height,
          child: Listener(
            onPointerUp: (event) =>
                _handlePointerEnd(event, slot, cancel: false),
            onPointerCancel: (event) =>
                _handlePointerEnd(event, slot, cancel: true),
            onPointerDown: (event) => _handlePointerDown(event, center, slot),
            onPointerMove: _handlePointerMove,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragUpdate: (_) {},
              onHorizontalDragEnd: (_) {},
              onHorizontalDragCancel: () => _finish(slot, cancel: true),
              child: GlassSurface(
                mode: widget.glassMode,
                reduceTransparency: widget.reduceTransparency,
                radius: height / 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: GlassMotionSelection(
                          center: Offset(center, height / 2),
                          size: Size(slot - 4, height - 4),
                          active:
                              active &&
                              !MediaQuery.disableAnimationsOf(context),
                          mode: widget.glassMode,
                          reduceTransparency: widget.reduceTransparency,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < widget.destinations.length; i++)
                          Expanded(
                            child: MergeSemantics(
                              child: Semantics(
                                label: widget.destinations[i].label,
                                button: true,
                                selected: widget.selectedIndex == i,
                                child: Tooltip(
                                  message: widget.destinations[i].label,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(44, 44),
                                      foregroundColor:
                                          i == (center / slot - .5).round()
                                          ? AppColors.primary
                                          : AppColors.muted,
                                    ),
                                    onPressed: () => _handleDestinationTap(i),
                                    child: ExcludeSemantics(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            widget.destinations[i].icon,
                                            size: 22 - 4 * second,
                                          ),
                                          if (first < 1)
                                            SizedBox(
                                              height:
                                                  (MediaQuery.textScalerOf(
                                                            context,
                                                          ).scale(11) *
                                                          1.2 +
                                                      3) *
                                                  (1 - first),
                                              child: Opacity(
                                                opacity: (1 - first * 2).clamp(
                                                  0,
                                                  1,
                                                ),
                                                child: Text(
                                                  widget.destinations[i].label,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    height: 1.2,
                                                  ),
                                                  overflow: TextOverflow.clip,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 宽屏横向文字顶部导航栏。
class AppTopNavigation extends StatelessWidget {
  const AppTopNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < destinations.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Semantics(
            selected: i == selectedIndex,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(96, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                backgroundColor: i == selectedIndex
                    ? AppColors.greenSoft
                    : Colors.transparent,
                foregroundColor: i == selectedIndex
                    ? AppColors.primary
                    : AppColors.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => onSelected(i),
              child: Text(destinations[i].label),
            ),
          ),
        ],
      ],
    ),
  );
}
