import 'types.dart';

/// 非原生平台登录流程占位实现，调用时提示使用浏览器弹窗登录。
class FlowExecutor {
  FlowExecutor(AuthentikConfig config);

  /// 占位运行入口，始终抛出平台不支持错误。
  Future<Uri> run({
    required Uri authorizationUri,
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async => throw const AuthFailure('unsupported_platform', '请使用浏览器弹窗登录。');

  /// 空取消操作。
  void cancel() {}

  /// 空释放操作。
  Future<void> dispose() async {}
}
