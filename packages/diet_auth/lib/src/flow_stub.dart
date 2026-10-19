import 'types.dart';

class FlowExecutor {
  FlowExecutor(AuthentikConfig config);

  Future<Uri> run({
    required Uri authorizationUri,
    required String username,
    required String password,
    Future<bool> Function(AuthentikConsent)? onConsent,
  }) async => throw const AuthFailure('unsupported_platform', '请使用浏览器弹窗登录。');

  void cancel() {}
  Future<void> dispose() async {}
}
