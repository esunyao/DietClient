import 'dart:typed_data';

import 'package:diet_ui/diet_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nutrition/application/meal_photo_providers.dart';
import '../../../../core/nutrition/application/nutrition_manager.dart';
import '../../../../core/presentation/navigation_manager.dart';
import '../../../../core/session/session_controller.dart';

/// 餐食照片展示与读取门控 Provider，仅在活动会话存在时启用照片读取。
final mealPhotoPresentationEnabledProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider) != null,
);

/// 将餐食照片异步结果映射为界面，并在同账户签名刷新期间保留已有内容，避免组件频繁销毁重建。
Widget mealPhotoContent(
  AsyncValue<MealPhotoSet> result,
  int epoch, {
  required Widget Function(MealPhotoSet) data,
  required Widget Function() loading,
  required Widget Function(Object, StackTrace) error,
}) {
  final previous = result.value;
  if (result.isLoading && previous?.sessionEpoch != epoch) return loading();
  return result.when(
    skipLoadingOnRefresh: true,
    skipLoadingOnReload: true,
    skipError: previous?.sessionEpoch == epoch,
    data: data,
    loading: loading,
    error: error,
  );
}

/// 餐食照片加载中、空态或错误重试占位组件。
class MealPhotoStatus extends StatelessWidget {
  const MealPhotoStatus({
    super.key,
    required this.label,
    this.loading = false,
    this.retry,
  });

  final String label;
  final bool loading;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.canvas,
    child: Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 150;
          final displayLabel = compact ? _compactLabel(label) : label;
          return Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (retry == null)
                  const Icon(Icons.photo_outlined, color: AppColors.muted),
                Flexible(
                  child: Tooltip(
                    message: label,
                    child: Text(
                      displayLabel,
                      textAlign: TextAlign.center,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: label,
                      style: compact
                          ? const TextStyle(fontSize: 11, height: 1.15)
                          : null,
                    ),
                  ),
                ),
                if (retry != null)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: '$label，重试',
                    onPressed: retry,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );

  static String _compactLabel(String label) => switch (label) {
    '读取照片信息' => '读取信息',
    '加载照片' => '加载中',
    '照片信息加载失败' => '信息失败',
    '照片加载失败' => '加载失败',
    '照片无法显示' => '图片损坏',
    '照片链接暂不可用' => '链接缺失',
    _ => label,
  };
}

/// 餐食历史卡片封面组件，展示首张照片与总张数徽章。
class MealPhotoCover extends ConsumerWidget {
  const MealPhotoCover({
    super.key,
    required this.mealId,
    required this.onOpen,
    this.decodeWidth = 288,
  });

  final String mealId;
  final ValueChanged<String> onOpen;
  final int decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mealPhotoPresentationEnabledProvider)) {
      return const MealPhotoStatus(label: '暂无照片');
    }
    final epoch = ref.watch(sessionEpochProvider);
    final result = ref.watch(mealPhotosProvider(mealId));
    return mealPhotoContent(
      result,
      epoch,
      loading: () => const MealPhotoStatus(label: '读取照片信息', loading: true),
      error: (_, _) => MealPhotoStatus(
        label: '照片信息加载失败',
        retry: () => ref.read(nutritionManagerProvider).refreshPhotos(mealId),
      ),
      data: (set) {
        if (set.photos.isEmpty) return const MealPhotoStatus(label: '暂无照片');
        final photo = set.photos.first;
        return Stack(
          fit: StackFit.expand,
          children: [
            MealPhotoImage(
              mealId: mealId,
              photo: photo,
              decodeWidth: decodeWidth,
              onTap: () => onOpen(photo.imageId),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _PhotoCountBadge(count: set.photos.length),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          '$count 张',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    ),
  );
}

/// 单张餐食照片渲染组件，区分链接缺失、字节加载与解码失败重试路径。
class MealPhotoImage extends ConsumerWidget {
  const MealPhotoImage({
    super.key,
    required this.mealId,
    required this.photo,
    this.decodeWidth,
    this.fit = BoxFit.cover,
    this.onTap,
    this.onDoubleTap,
    this.onDoubleTapDown,
  });

  final String mealId;
  final MealPhoto photo;
  final int? decodeWidth;
  final BoxFit fit;
  final VoidCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureTapDownCallback? onDoubleTapDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(sessionEpochProvider);
    if (!ref.watch(mealPhotoPresentationEnabledProvider)) {
      return const MealPhotoStatus(label: '暂无照片');
    }
    if (photo.previewUrl == null || photo.previewUrl!.trim().isEmpty) {
      return MealPhotoStatus(
        label: '照片链接暂不可用',
        retry: () => ref.read(nutritionManagerProvider).refreshPhotos(mealId),
      );
    }
    final key = (mealId: mealId, imageId: photo.imageId);
    final result = ref.watch(mealPhotoBytesProvider(key));
    void retryBytes() =>
        ref.read(nutritionManagerProvider).refreshPhotoBytes(key);
    return result.when(
      skipLoadingOnRefresh: false,
      loading: () => const MealPhotoStatus(label: '加载照片', loading: true),
      error: (_, _) => MealPhotoStatus(label: '照片加载失败', retry: retryBytes),
      data: (bytes) => Semantics(
        label: '查看餐食照片 ${photo.slotNo}',
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onDoubleTapDown: onDoubleTapDown,
          child: OwnedMealImage(
            key: ValueKey((epoch, mealId, photo.imageId)),
            bytes: bytes,
            decodeWidth: decodeWidth,
            fit: fit,
            errorBuilder: (_, _, _) =>
                MealPhotoStatus(label: '照片无法显示', retry: retryBytes),
          ),
        ),
      ),
    );
  }
}

/// 持有独立解码缓存键的餐食图片组件，销毁或变更时自动驱逐自身缓存。
class OwnedMealImage extends StatefulWidget {
  const OwnedMealImage({
    super.key,
    required this.bytes,
    required this.fit,
    required this.errorBuilder,
    this.decodeWidth,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final int? decodeWidth;
  final ImageErrorWidgetBuilder errorBuilder;

  @override
  State<OwnedMealImage> createState() => _OwnedMealImageState();
}

class _OwnedMealImageState extends State<OwnedMealImage> {
  late ImageProvider _image;

  void _create() {
    // 为每个组件实例复制独立字节，隔离跨实例与跨会话的解码缓存生命周期。
    final memory = MemoryImage(Uint8List.fromList(widget.bytes));
    _image = widget.decodeWidth == null
        ? memory
        : ResizeImage(
            memory,
            width: widget.decodeWidth,
            height: widget.decodeWidth,
            policy: ResizeImagePolicy.fit,
          );
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(OwnedMealImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.decodeWidth != widget.decodeWidth) {
      _image.evict();
      _create();
    }
  }

  @override
  void dispose() {
    _image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _image,
    fit: widget.fit,
    errorBuilder: widget.errorBuilder,
    gaplessPlayback: false,
    excludeFromSemantics: true,
  );
}

/// 餐食详情横向照片缩略图条，点击后以当前图片 ID 打开全屏相册。
class MealPhotoStrip extends ConsumerWidget {
  const MealPhotoStrip({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(sessionEpochProvider);
    final result = ref.watch(mealPhotoPresentationEnabledProvider)
        ? ref.watch(mealPhotosProvider(mealId))
        : AsyncValue<MealPhotoSet>.data(
            MealPhotoSet(mealId: mealId, captureSessionId: '', photos: []),
          );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '本餐照片'),
          const SizedBox(height: 12),
          mealPhotoContent(
            result,
            epoch,
            loading: () => const SizedBox(
              height: 120,
              child: MealPhotoStatus(label: '读取照片信息', loading: true),
            ),
            error: (_, _) => SizedBox(
              height: 120,
              child: MealPhotoStatus(
                label: '照片信息加载失败',
                retry: () =>
                    ref.read(nutritionManagerProvider).refreshPhotos(mealId),
              ),
            ),
            data: (set) => set.photos.isEmpty
                ? const Text('暂无照片')
                : SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: set.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _PhotoThumbnailTile(
                        mealId: mealId,
                        photo: set.photos[index],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnailTile extends ConsumerWidget {
  const _PhotoThumbnailTile({required this.mealId, required this.photo});

  final String mealId;
  final MealPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: 144,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MealPhotoImage(
        mealId: mealId,
        photo: photo,
        decodeWidth: 432,
        onTap: () => ref
            .read(navigationManagerProvider)
            .openMealPhotos(context, mealId, imageId: photo.imageId),
      ),
    ),
  );
}
