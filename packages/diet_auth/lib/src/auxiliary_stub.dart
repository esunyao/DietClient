import 'package:dio/dio.dart';

import 'types.dart';

/// 非原生平台注册与邮件重发占位执行器。
class AuxiliaryFlowExecutor {
  AuxiliaryFlowExecutor(AuthentikConfig config, {Dio? dio});

  /// 网页端暂不支持真实注册，始终抛出平台不支持错误。
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) async => throw const AuthFailure('unsupported_platform', '网页端暂不支持真实注册。');

  /// 网页端暂不支持邮件重发，始终抛出平台不支持错误。
  Future<void> resend(String email) async =>
      throw const AuthFailure('unsupported_platform', '网页端暂不支持邮件重发。');

  /// 空取消操作。
  void cancel() {}

  /// 空释放操作。
  Future<void> dispose() async {}
}
