/// @brief 历史餐食照片的内存元数据模型。
/// @details 保留精确图片 ID、槽位和可空预览签名信息。
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

/// @brief 关联餐食与采集会话的照片集合快照。
/// @details 内部照片列表在构造时复制为不可修改的只读集合。
class MealPhotoSet {
  MealPhotoSet({
    required this.mealId,
    required this.captureSessionId,
    required List<MealPhoto> photos,
    this.sessionEpoch = 0,
  }) : photos = List.unmodifiable(photos);

  final String mealId;
  final String captureSessionId;

  /// @brief Local owner session epoch generation.
  /// @note Never part of the HTTP contract or persistence.
  final int sessionEpoch;
  final List<MealPhoto> photos;
}
