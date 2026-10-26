typedef NutriJson = Map<String, dynamic>;
NutriJson nutriJson(Object? value) => Map<String, dynamic>.from(value as Map);
List<T> _list<T>(Object? value, T Function(NutriJson) parse) => (value as List)
    .map((item) => parse(nutriJson(item)))
    .toList(growable: false);
double? _number(Object? value) => value == null ? null : double.parse('$value');
String _id(Object? value) {
  final id = '$value';
  if (!RegExp(r'^\d+$').hasMatch(id)) {
    throw const FormatException('Invalid identifier');
  }
  return id;
}

class CapturePolicy {
  CapturePolicy.fromJson(NutriJson j)
    : maxImageCount = j['maxImageCount'] as int,
      maxFileSizeBytes = j['maxFileSizeBytes'] as int,
      allowedContentTypes = List<String>.from(j['allowedContentTypes'] as List),
      sessionExpiresInSeconds = j['sessionExpiresInSeconds'] as int,
      maxDraftSessionCount = j['maxDraftSessionCount'] as int,
      draftExpiresInSeconds = j['draftExpiresInSeconds'] as int;
  final int maxImageCount,
      maxFileSizeBytes,
      sessionExpiresInSeconds,
      maxDraftSessionCount,
      draftExpiresInSeconds;
  final List<String> allowedContentTypes;
}

class CaptureImage {
  CaptureImage.fromJson(NutriJson j)
    : imageId = _id(j['imageId']),
      slotNo = j['slotNo'] as int,
      objectKey = j['objectKey'] as String,
      contentType = j['contentType'] as String,
      contentLength = j['contentLength'] as int,
      capturedAt = j['capturedAt'] == null
          ? null
          : DateTime.parse(j['capturedAt'] as String),
      status = j['status'] as String,
      createdAt = DateTime.parse(j['createdAt'] as String),
      previewUrl = j['previewUrl'] as String?,
      previewExpiresInSeconds = j['previewExpiresInSeconds'] as int?;
  final String imageId, objectKey, contentType, status;
  final int slotNo, contentLength;
  final DateTime? capturedAt;
  final DateTime createdAt;
  final String? previewUrl;
  final int? previewExpiresInSeconds;
}

class CaptureSession {
  CaptureSession.fromJson(NutriJson j)
    : captureSessionId = j['captureSessionId'] as String,
      status = j['status'] as String,
      timezone = j['timezone'] as String,
      maxImageCount = j['maxImageCount'] as int,
      expiresAt = DateTime.parse(j['expiresAt'] as String),
      analysisRequestedAt = j['analysisRequestedAt'] == null
          ? null
          : DateTime.parse(j['analysisRequestedAt'] as String),
      images = _list(j['images'], CaptureImage.fromJson),
      createdAt = DateTime.parse(j['createdAt'] as String),
      updatedAt = DateTime.parse(j['updatedAt'] as String);
  final String captureSessionId, status, timezone;
  final int maxImageCount;
  final DateTime expiresAt, createdAt, updatedAt;
  final DateTime? analysisRequestedAt;
  final List<CaptureImage> images;
  // Signature lifetime starts when this response is received, not on each view.
  final DateTime previewReceivedAt = DateTime.now().toUtc();
}

class CaptureDraft {
  CaptureDraft.fromJson(NutriJson j)
    : captureSessionId = j['captureSessionId'] as String,
      status = j['status'] as String,
      confirmedImageCount = j['confirmedImageCount'] as int,
      maxImageCount = j['maxImageCount'] as int,
      expiresAt = DateTime.parse(j['expiresAt'] as String),
      createdAt = DateTime.parse(j['createdAt'] as String),
      updatedAt = DateTime.parse(j['updatedAt'] as String),
      images = _list(j['images'], CaptureImage.fromJson);
  final String captureSessionId, status;
  final int confirmedImageCount, maxImageCount;
  final DateTime expiresAt, createdAt, updatedAt;
  final List<CaptureImage> images;
}

class CaptureDraftPage {
  CaptureDraftPage.fromJson(NutriJson j)
    : items = _list(j['items'], CaptureDraft.fromJson),
      total = j['total'] as int;
  final List<CaptureDraft> items;
  final int total;
}

class PresignedImage {
  PresignedImage.fromJson(NutriJson j)
    : imageId = _id(j['imageId']),
      uploadUrl = j['uploadUrl'] as String,
      objectKey = j['objectKey'] as String,
      expiresInSeconds = j['expiresInSeconds'] as int,
      requiredHeaders = Map<String, String>.from(j['requiredHeaders'] as Map);
  final String imageId, uploadUrl, objectKey;
  final int expiresInSeconds;
  final Map<String, String> requiredHeaders;
}

class NutrientValue {
  NutrientValue.fromJson(NutriJson j)
    : nutrientCode = j['nutrientCode'] as String,
      nutrientName = j['nutrientName'] as String,
      unit = j['unit'] as String,
      amount = _number(j['amount'])!;
  final String nutrientCode, nutrientName, unit;
  final double amount;
}

double? nutrientAmount(List<NutrientValue> values, String code) {
  for (final value in values) {
    if (value.nutrientCode == code) return value.amount;
  }
  return null;
}

class MealItem {
  MealItem.fromJson(NutriJson j)
    : itemId = _id(j['itemId']),
      sequenceNo = j['sequenceNo'] as int,
      displayName = j['displayName'] as String,
      estimatedWeightG = _number(j['estimatedWeightG']),
      confidence = _number(j['confidence']),
      dataSource = j['dataSource'] as String,
      userCorrected = j['userCorrected'] as bool,
      notes = j['notes'] as String?,
      nutrients = _list(j['nutrients'], NutrientValue.fromJson);
  final String itemId, displayName, dataSource;
  final int sequenceNo;
  final double? estimatedWeightG, confidence;
  final bool userCorrected;
  final String? notes;
  final List<NutrientValue> nutrients;
}

class MealHistoryItem {
  MealHistoryItem.fromJson(NutriJson j)
    : mealId = _id(j['mealId']),
      mealType = j['mealType'] as String,
      consumedAt = DateTime.parse(j['consumedAt'] as String),
      localDate = j['localDate'] as String,
      notes = j['notes'] as String?,
      analysisStatus = j['analysisStatus'] as String,
      nutrients = _list(j['nutrients'], NutrientValue.fromJson);
  final String mealId, mealType, localDate, analysisStatus;
  final String? notes;
  final DateTime consumedAt;
  final List<NutrientValue> nutrients;
}

class Meal extends MealHistoryItem {
  Meal.fromJson(super.j)
    : captureSessionId = j['captureSessionId'] as String,
      timezone = j['timezone'] as String,
      items = _list(j['items'], MealItem.fromJson),
      createdAt = DateTime.parse(j['createdAt'] as String),
      updatedAt = DateTime.parse(j['updatedAt'] as String),
      super.fromJson();
  final String captureSessionId, timezone;
  final List<MealItem> items;
  final DateTime createdAt, updatedAt;
}

class MealPage {
  MealPage.fromJson(NutriJson j)
    : items = _list(j['items'], MealHistoryItem.fromJson),
      page = j['page'] as int,
      pageSize = j['pageSize'] as int,
      total = int.parse('${j['total']}');
  final List<MealHistoryItem> items;
  final int page, pageSize, total;
}

class CaptureSubmission {
  CaptureSubmission.fromJson(NutriJson j)
    : captureSession = CaptureSession.fromJson(nutriJson(j['captureSession'])),
      meal = Meal.fromJson(nutriJson(j['meal']));
  final CaptureSession captureSession;
  final Meal meal;
}

class DailyMealBreakdown {
  DailyMealBreakdown.fromJson(NutriJson j)
    : mealType = j['mealType'] as String,
      mealCount = j['mealCount'] as int,
      nutrients = _list(j['nutrients'], NutrientValue.fromJson);
  final String mealType;
  final int mealCount;
  final List<NutrientValue> nutrients;
}

class DailySummary {
  DailySummary.fromJson(NutriJson j)
    : localDate = j['localDate'] as String,
      mealCount = j['mealCount'] as int,
      nutrients = _list(j['nutrients'], NutrientValue.fromJson),
      mealBreakdown = _list(j['mealBreakdown'], DailyMealBreakdown.fromJson),
      updatedAt = DateTime.parse(j['updatedAt'] as String);
  final String localDate;
  final int mealCount;
  final List<NutrientValue> nutrients;
  final List<DailyMealBreakdown> mealBreakdown;
  final DateTime updatedAt;
}

class DailyTrend {
  DailyTrend.fromJson(NutriJson j)
    : dateFrom = j['dateFrom'] as String,
      dateTo = j['dateTo'] as String,
      days = _list(j['days'], DailySummary.fromJson);
  final String dateFrom, dateTo;
  final List<DailySummary> days;
}

class MealNutrientInput {
  const MealNutrientInput({required this.nutrientCode, required this.amount});
  final String nutrientCode;
  final double amount;
  NutriJson toJson() => {'nutrientCode': nutrientCode, 'amount': amount};
}

class MealCorrectionItem {
  const MealCorrectionItem({
    this.itemId,
    required this.displayName,
    this.estimatedWeightG,
    this.notes,
    required this.nutrients,
  });
  final String? itemId;
  final String displayName;
  final double? estimatedWeightG;
  final String? notes;
  final List<MealNutrientInput> nutrients;
  NutriJson toJson() => {
    'itemId': itemId,
    'displayName': displayName,
    'estimatedWeightG': estimatedWeightG,
    'notes': notes,
    'nutrients': nutrients.map((v) => v.toJson()).toList(),
  };
}

class MealCorrection {
  const MealCorrection({
    required this.mealType,
    required this.consumedAt,
    required this.timezone,
    this.notes,
    required this.items,
  });
  final String mealType, timezone;
  final DateTime consumedAt;
  final String? notes;
  final List<MealCorrectionItem> items;
  NutriJson toJson() => {
    'mealType': mealType,
    'consumedAt': consumedAt.toUtc().toIso8601String(),
    'timezone': timezone,
    'notes': notes,
    'items': items.map((v) => v.toJson()).toList(),
  };
}

/// Value equality makes provider families stable across widget rebuilds.
typedef MealQuery = ({
  String? dateFrom,
  String? dateTo,
  String? mealType,
  String? keyword,
  int page,
  int pageSize,
});
const defaultMealQuery = (
  dateFrom: null,
  dateTo: null,
  mealType: null,
  keyword: null,
  page: 1,
  pageSize: 20,
);
typedef TrendQuery = ({String dateFrom, String dateTo});
