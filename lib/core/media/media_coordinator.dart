import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/session_controller.dart';

/// 选图业务用途分类。
enum MediaPurpose { avatar, meal }

/// 经大小、格式与解码校验通过的本地图片结果。
class SelectedImage {
  const SelectedImage({
    required this.file,
    required this.bytes,
    required this.contentType,
  });
  final XFile file;
  final Uint8List bytes;
  final String contentType;
}

/// 从实际字节识别 JPEG、PNG 或 WebP 格式并校验首帧可解码及不超过 2500 万像素。
String actualImageType(Uint8List bytes) {
  final decoder = image.findDecoderForData(bytes);
  final type = switch (decoder) {
    image.JpegDecoder() => 'image/jpeg',
    image.PngDecoder() => 'image/png',
    image.WebPDecoder() => 'image/webp',
    _ => throw const FormatException('请选择 JPEG、PNG 或 WebP 图片'),
  };
  final info = decoder!.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 25000000 ||
      decoder.decodeFrame(0) == null) {
    throw const FormatException('图片不可读取或超过 2500 万像素');
  }
  return type;
}

/// 媒体协调器 Provider。
final mediaCoordinatorProvider = Provider<MediaCoordinator>(
  (ref) => MediaCoordinator(ref),
);

/// 图片选择、Android 丢失结果恢复与格式校验协调器；仅本类调用 `retrieveLostData`，恢复绝不触发上传。
class MediaCoordinator {
  MediaCoordinator(this.ref, {ImagePicker? picker, this.preferences})
    : _picker = picker ?? ImagePicker();
  final Ref ref;
  final ImagePicker _picker;
  final SharedPreferencesAsync? preferences;
  Future<void>? _recovery;
  final Map<String, List<XFile>> _recovered = {};
  String? _recoveredOwner;
  int? _recoveredEpoch;
  bool _picking = false;
  static const _key = 'diet.pendingPicker.v1';
  String? get _owner {
    final identity = ref.read(sessionProvider)?.identity;
    return identity == null
        ? null
        : jsonEncode([identity.issuer, identity.subject, identity.clientId]);
  }

  String _purpose(MediaPurpose purpose, String? contextId) =>
      '${purpose.name}:${contextId ?? ''}';

  /// 调用系统选图器选取图片；仅负责选图，不读取内容或上传。
  Future<XFile?> pick({
    required MediaPurpose purpose,
    required ImageSource source,
    String? contextId,
  }) async {
    if (_picking) throw StateError('图片选择正在进行');
    _picking = true;
    final epoch = ref.read(sessionEpochProvider), owner = _owner;
    final prefs = preferences ?? SharedPreferencesAsync();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        if (owner != null) {
          await prefs.setString(
            _key,
            jsonEncode({
              'owner': owner,
              'purpose': _purpose(purpose, contextId),
              'at': DateTime.now().toUtc().toIso8601String(),
            }),
          );
        } else {
          await prefs.remove(_key);
        }
      }
      final result = await _picker.pickImage(source: source);
      return ref.mounted && ref.read(sessionEpochProvider) == epoch
          ? result
          : null;
    } finally {
      _picking = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await prefs.remove(_key);
      }
    }
  }

  /// 恢复 Android 丢失选图数据并按账户、登录代次与用途消费暂存文件；不会触发上传。
  Future<List<XFile>> recover({
    required MediaPurpose purpose,
    String? contextId,
  }) async {
    _recovery ??= _recover();
    await _recovery;
    if (_recoveredOwner != _owner ||
        _recoveredEpoch != ref.read(sessionEpochProvider)) {
      _recovered.clear();
      return [];
    }
    return _recovered.remove(_purpose(purpose, contextId)) ?? [];
  }

  Future<void> _recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _picking) {
      return;
    }
    final prefs = preferences ?? SharedPreferencesAsync();
    final owner = _owner, epoch = ref.read(sessionEpochProvider);
    // 先移除持久化标记，再消费平台丢失结果；只有归属匹配且不足一小时才暂存。
    final raw = await prefs.getString(_key);
    await prefs.remove(_key);
    final lost = await _picker.retrieveLostData();
    if (raw == null ||
        owner == null ||
        !ref.mounted ||
        ref.read(sessionEpochProvider) != epoch ||
        lost.files?.isNotEmpty != true) {
      return;
    }
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().toUtc().difference(
        DateTime.parse(saved['at'] as String),
      );
      if (saved['owner'] == owner &&
          age >= Duration.zero &&
          age < const Duration(hours: 1)) {
        _recoveredOwner = owner;
        _recoveredEpoch = epoch;
        _recovered[saved['purpose'] as String] = lost.files!;
      }
    } on FormatException {
      // 无归属或格式失效的恢复记录直接丢弃。
    }
  }

  /// 检查图片文件的大小上限、真实字节格式与允许 MIME 白名单。
  Future<SelectedImage> inspect(
    XFile file, {
    required int maxBytes,
    required List<String> allowedContentTypes,
  }) async {
    if (await file.length() > maxBytes) throw const FormatException('图片超过大小限制');
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const FormatException('图片超过大小限制');
    final type = await compute(actualImageType, bytes);
    if (!allowedContentTypes.contains(type)) {
      throw const FormatException('图片格式不受支持');
    }
    return SelectedImage(file: file, bytes: bytes, contentType: type);
  }
}
