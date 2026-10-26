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
