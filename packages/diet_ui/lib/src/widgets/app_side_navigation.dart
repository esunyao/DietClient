import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'app_icons.dart';
import 'app_navigation.dart';
import 'glass_surface.dart';

/// 桌面覆盖侧栏。应用负责路由、账户菜单与菜单打开状态。
class AppSideNavigation extends StatefulWidget {
  const AppSideNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    required this.accountBuilder,
    this.menuOpen = false,
    this.glassMode = GlassMode.standard,
    this.reduceTransparency = false,
  });

  final List<AppNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettings;
  final Widget Function(bool expanded) accountBuilder;
  final bool menuOpen;
  final GlassMode glassMode;
  final bool reduceTransparency;

  @override
  State<AppSideNavigation> createState() => _AppSideNavigationState();
}

class _AppSideNavigationState extends State<AppSideNavigation>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  Timer? _timer;
  bool _hover = false;
  bool _pointerInside = false;
  bool _focus = false;
  bool _pinned = false;
  final _focusNode = FocusNode();
  bool _keyboardInput = true;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      _keyboardInput = true;
      if (_focusNode.hasFocus) {
        _focus = true;
        _update();
      }
    }
    return false;
  }

  void _update() {
    final expand = _hover || _focus || _pinned || widget.menuOpen;
    final target = expand ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = target;
    } else {
      _animation.animateTo(
        target,
        duration: Duration(milliseconds: expand ? 240 : 200),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _hoverChanged(bool value) {
    _pointerInside = value;
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: value ? 120 : 180), () {
      _hover = value;
      _update();
    });
  }

  @override
  void didUpdateWidget(AppSideNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuOpen != widget.menuOpen) _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _focusNode.dispose();
    _animation.dispose();
    super.dispose();
  }

  Widget _entry(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool selected = false,
    required double progress,
  }) {
    final labelOpacity = ((progress - .65) / .35).clamp(0.0, 1.0);
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 11, height: 1.2),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 56);
    final height = 27 + text.height;
    text.dispose();
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppColors.primary : AppColors.muted,
            backgroundColor: selected
                ? AppColors.greenSoft
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: SizedBox(
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  excluding: labelOpacity > 0,
                  child: Opacity(
                    opacity: 1 - labelOpacity,
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 22),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ExcludeSemantics(
                  excluding: labelOpacity == 0,
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Row(
                      children: [
                        Icon(icon, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(label)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _hoverChanged(true),
    onExit: (_) => _hoverChanged(false),
    child: Listener(
      onPointerDown: (_) {
        _keyboardInput = false;
        _focus = false;
        _update();
      },
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (value) {
          _focus = value && _keyboardInput;
          _update();
        },
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => SizedBox(
            width: 96 + 120 * _animation.value,
            child: GlassSurface(
              radius: 24,
              mode: widget.glassMode,
              reduceTransparency: widget.reduceTransparency,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _entry('膳食健康', AppIcons.bowlFood, () {
                              if (_pointerInside) return;
                              _pinned = !_pinned;
                              _update();
                            }, progress: _animation.value),
                            const SizedBox(height: 18),
                            for (var i = 0; i < widget.destinations.length; i++)
                              _entry(
                                widget.destinations[i].label,
                                widget.destinations[i].icon,
                                () => widget.onSelected(i),
                                selected: i == widget.selectedIndex,
                                progress: _animation.value,
                              ),
                            const Spacer(),
                            const SizedBox(height: 18),
                            _entry(
                              '设置',
                              AppIcons.settings,
                              widget.onSettings,
                              progress: _animation.value,
                            ),
                            widget.accountBuilder(_animation.value > .65),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
