import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/meal_photo_providers.dart';
import '../../../../core/nutrition/application/nutrition_manager.dart';
import '../../../../core/presentation/app_routes.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/presentation/ui_preferences.dart';
import '../../../../core/session/session_controller.dart';
import '../widgets/meal_photo_widgets.dart';

/// 原生餐食全屏照片相册页，支持多图翻页、双击缩放及键盘方向键切换。
class NativeMealGalleryScreen extends ConsumerWidget {
  const NativeMealGalleryScreen({
    super.key,
    required this.mealId,
    this.imageId,
  });

  final String mealId;
  final String? imageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.read(navigationManagerProvider);
    void close() =>
        navigation.returnOrFallback(context, AppRoutes.mealDetail(mealId));
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('餐食照片')),
        body: const Center(child: Text('Web 暂未接入真实餐食照片')),
      );
    }
    // 无活动会话时不装配真实照片查询，元数据状态交由共享照片边界处理。
    final result = ref.watch(mealPhotoPresentationEnabledProvider)
        ? ref.watch(mealPhotosProvider(mealId))
        : AsyncValue<MealPhotoSet>.data(
            MealPhotoSet(mealId: mealId, captureSessionId: '', photos: []),
          );
    final epoch = ref.watch(sessionEpochProvider);
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        ref.watch(uiPreferencesProvider.select((value) => value.reduceMotion));

    return PopScope<Object?>(
      canPop: navigation.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(
              backgroundColor: AppColors.canvas,
              leading: IconButton(
                tooltip: '关闭相册',
                icon: const Icon(Icons.close),
                onPressed: close,
              ),
              title: const Text('餐食照片'),
            ),
            body: SafeArea(
              top: false,
              child: mealPhotoContent(
                result,
                epoch,
                loading: () =>
                    const MealPhotoStatus(label: '读取照片信息', loading: true),
                error: (_, _) => MealPhotoStatus(
                  label: '照片信息加载失败',
                  retry: () =>
                      ref.read(nutritionManagerProvider).refreshPhotos(mealId),
                ),
                data: (set) => set.photos.isEmpty
                    ? const MealPhotoStatus(label: '暂无照片')
                    : _GalleryPages(
                        key: ValueKey((epoch, mealId)),
                        mealId: mealId,
                        photos: set.photos,
                        imageId: imageId,
                        reduceMotion: reduceMotion,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryPages extends StatefulWidget {
  const _GalleryPages({
    super.key,
    required this.mealId,
    required this.photos,
    required this.reduceMotion,
    this.imageId,
  });

  final String mealId;
  final List<MealPhoto> photos;
  final String? imageId;
  final bool reduceMotion;

  @override
  State<_GalleryPages> createState() => _GalleryPagesState();
}

class _GalleryPagesState extends State<_GalleryPages> {
  late final PageController _pages;
  final _keyboardFocus = FocusNode();
  late int _index;
  bool _zoomed = false;

  int _find(String? id) {
    final index = widget.photos.indexWhere((photo) => photo.imageId == id);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _index = _find(widget.imageId);
    _pages = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_GalleryPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 照片集合刷新后尽量保持当前浏览的图片位置，找不到时回到首图。
    final oldIndex = _index < oldWidget.photos.length
        ? _index
        : oldWidget.photos.length - 1;
    final oldId = oldWidget.photos[oldIndex].imageId;
    final next = _find(
      widget.imageId != oldWidget.imageId ? widget.imageId : oldId,
    );
    if (next != _index) {
      setState(() {
        _index = next;
        _zoomed = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(next);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final target = _index + delta;
    if (_zoomed || target < 0 || target >= widget.photos.length) return;
    if (widget.reduceMotion) {
      _pages.jumpToPage(target);
      return;
    }
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
    },
    child: Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const ValueKey('meal-photo-pages'),
              controller: _pages,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() {
                _index = value;
                _zoomed = false;
              }),
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _ZoomPhoto(
                  key: ValueKey(photo.imageId),
                  mealId: widget.mealId,
                  photo: photo,
                  active: index == _index,
                  onZoom: (zoomed) {
                    if (mounted && _zoomed != zoomed) {
                      setState(() => _zoomed = zoomed);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一张',
                  onPressed: !_zoomed && _index > 0 ? () => _move(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Flexible(
                  child: Text(
                    '${_index + 1} / ${widget.photos.length}',
                    semanticsLabel:
                        '第 ${_index + 1} 张，共 ${widget.photos.length} 张',
                  ),
                ),
                IconButton(
                  tooltip: '下一张',
                  onPressed: !_zoomed && _index + 1 < widget.photos.length
                      ? () => _move(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ZoomPhoto extends StatefulWidget {
  const _ZoomPhoto({
    super.key,
    required this.mealId,
    required this.photo,
    required this.active,
    required this.onZoom,
  });

  final String mealId;
  final MealPhoto photo;
  final bool active;
  final ValueChanged<bool> onZoom;

  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
    if (widget.active) widget.onZoom(zoomed);
  }

  @override
  void didUpdateWidget(_ZoomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _transform.value = Matrix4.identity();
    }
  }

  // 在原始比例与围绕双击位置 2.5x 放大之间切换。
  void _doubleTap() {
    _transform.value = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..setEntry(0, 0, 2.5)
            ..setEntry(1, 1, 2.5)
            ..setEntry(0, 3, -_tap.dx * 1.5)
            ..setEntry(1, 3, -_tap.dy * 1.5));
  }

  @override
  void dispose() {
    _transform.removeListener(_changed);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          // 原尺寸下保留单指横向滑动给 PageView 翻页；双指捏合仍可触发缩放。
          gestureSettings: _zoomed
              ? media.gestureSettings
              : DeviceGestureSettings(
                  touchSlop: constraints.biggest.longestSide,
                ),
        ),
        child: InteractiveViewer(
          transformationController: _transform,
          panEnabled: _zoomed,
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: MealPhotoImage(
              mealId: widget.mealId,
              photo: widget.photo,
              fit: BoxFit.contain,
              decodeWidth: 2048,
              onDoubleTapDown: (details) => _tap = details.localPosition,
              onDoubleTap: _doubleTap,
            ),
          ),
        ),
      );
    },
  );
}
