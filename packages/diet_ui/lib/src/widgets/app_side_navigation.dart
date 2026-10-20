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
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );
  bool _expanded = false;
  double get _progress => Curves.easeInOutCubic.transform(_animation.value);
  Timer? _timer;
  bool _hover = false;
  bool _pointerInside = false;
  bool _focus = false;
  bool _pinned = false;
  final _focusNode = FocusNode();
  bool _keyboardInput = true;
  static const _compactStyle = TextStyle(fontSize: 11, height: 1.2);
  static const _expandedStyle = TextStyle(fontSize: 14, height: 1.4);
  final _entrySizes = <String, ({double height, double expandedHeight})>{};

  void _measureEntries() {
    _entrySizes.clear();
    for (final label in [
      '膳食健康',
      ...widget.destinations.map((item) => item.label),
      '设置',
    ]) {
      final text = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );
      text.text = TextSpan(text: label, style: _compactStyle);
      text.layout(maxWidth: 56);
      final compactHeight = 27 + text.height;
      text.text = TextSpan(text: label, style: _expandedStyle);
      text.layout(maxWidth: 142);
      _entrySizes[label] = (
        height: compactHeight > text.height ? compactHeight : text.height,
        expandedHeight: text.height,
      );
      text.dispose();
    }
  }

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
      _expanded = expand;
      _animation.value = target;
    } else if (_expanded != expand) {
      _expanded = expand;
      if (expand) {
        _animation.forward();
      } else {
        _animation.reverse();
      }
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
    if (oldWidget.destinations != widget.destinations) _measureEntries();
    if (oldWidget.menuOpen != widget.menuOpen) _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureEntries();
    _update();
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
    final size = _entrySizes[label]!;
    final compactOpacity = 1 - (progress / .4).clamp(0.0, 1.0);
    final expandedOpacity = ((progress - .3) / .5).clamp(0.0, 1.0);
    return Semantics(
      label: label,
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
          child: ExcludeSemantics(
            child: ClipRect(
              child: SizedBox(
                height: size.height,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      start: 17 * (1 - progress),
                      top: (size.height - 22) / 2 * progress,
                      child: Icon(icon, size: 22),
                    ),
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      start: 0,
                      top: 27,
                      width: 56,
                      child: Opacity(
                        opacity: compactOpacity,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _compactStyle,
                        ),
                      ),
                    ),
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      start: 34,
                      top: (size.height - size.expandedHeight) / 2,
                      width: 142,
                      child: Opacity(
                        opacity: expandedOpacity,
                        child: Text(label, style: _expandedStyle),
                      ),
                    ),
                  ],
                ),
              ),
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
            width: 96 + 120 * _progress,
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
                            }, progress: _progress),
                            const SizedBox(height: 18),
                            for (var i = 0; i < widget.destinations.length; i++)
                              _entry(
                                widget.destinations[i].label,
                                widget.destinations[i].icon,
                                () => widget.onSelected(i),
                                selected: i == widget.selectedIndex,
                                progress: _progress,
                              ),
                            const Spacer(),
                            const SizedBox(height: 18),
                            _entry(
                              '设置',
                              AppIcons.settings,
                              widget.onSettings,
                              progress: _progress,
                            ),
                            widget.accountBuilder(_progress > .65),
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
