import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List prepareAvatar(Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('图片不能超过 5 MiB');
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder &&
      decoder is! img.PngDecoder &&
      decoder is! img.WebPDecoder) {
    throw const FormatException('请选择 JPEG、PNG 或 WebP 图片');
  }
  final info = decoder!.startDecode(bytes);
  if (info == null ||
      info.width * info.height > 25000000 ||
      info.width <= 0 ||
      info.height <= 0) {
    throw const FormatException('图片尺寸不可用或超过 2500 万像素');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('无法读取图片');
  var oriented = img.bakeOrientation(decoded);
  if (oriented.width > 2048 || oriented.height > 2048) {
    oriented = img.copyResize(
      oriented,
      width: oriented.width >= oriented.height ? 2048 : null,
      height: oriented.height > oriented.width ? 2048 : null,
    );
  }
  return Uint8List.fromList(img.encodePng(oriented));
}

Uint8List finishAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width != decoded.height) {
    throw const FormatException('请裁剪为方形图片');
  }
  return Uint8List.fromList(
    img.encodePng(img.copyResize(decoded, width: 512, height: 512)),
  );
}
