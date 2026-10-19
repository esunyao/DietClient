import 'package:flutter/widgets.dart';

/// 保留上游 Regular 字体；Flutter 3.47 的 IconData 为 final，不能继承。
/// 码点核对自 phosphor_flutter 2.1.0，避免导入其旧 IconData 子类。
@staticIconProvider
abstract final class AppIcons {
  static const home = IconData(
    0xe2c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const camera = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const plan = IconData(
    0xe262,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const trends = IconData(
    0xe154,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const reports = IconData(
    0xe23a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const profile = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
  static const sparkle = IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
}
