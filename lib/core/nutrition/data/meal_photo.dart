/// 历史餐食照片的内存元数据：保留精确图片 ID、槽位和可空预览签名信息。
class MealPhoto {
  const MealPhoto({
    required this.imageId,
    required this.slotNo,
    this.previewUrl,
    this.expiresAt,
  });

  final String imageId;
  final int slotNo;
  final String? previewUrl;
  final DateTime? expiresAt;
}

/// 关联餐食与采集会话的照片快照；照片列表复制为只读集合。
class MealPhotoSet {
  MealPhotoSet({
    required this.mealId,
    required this.captureSessionId,
    required List<MealPhoto> photos,
    this.sessionEpoch = 0,
  }) : photos = List.unmodifiable(photos);

  final String mealId;
  final String captureSessionId;

  /// Local owner generation, never part of the HTTP contract or persistence.
  final int sessionEpoch;
  final List<MealPhoto> photos;
}
