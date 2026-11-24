/// 历史餐食照片的内存元数据模型，保留精确图片 ID 与预览签名。
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

/// 关联餐食与采集会话的照片集合只读快照。
class MealPhotoSet {
  MealPhotoSet({
    required this.mealId,
    required this.captureSessionId,
    required List<MealPhoto> photos,
    this.sessionEpoch = 0,
  }) : photos = List.unmodifiable(photos);

  final String mealId;
  final String captureSessionId;

  /// 本地归属的登录代次，不参与接口传输或持久化。
  final int sessionEpoch;
  final List<MealPhoto> photos;
}
