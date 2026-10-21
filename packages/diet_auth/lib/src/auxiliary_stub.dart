import 'package:dio/dio.dart';

import 'types.dart';

class AuxiliaryFlowExecutor {
  AuxiliaryFlowExecutor(AuthentikConfig config, {Dio? dio});
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    String displayName = '',
  }) async => throw const AuthFailure('unsupported_platform', '网页端暂不支持真实注册。');
  Future<void> resend(String email) async =>
      throw const AuthFailure('unsupported_platform', '网页端暂不支持邮件重发。');
  void cancel() {}
  Future<void> dispose() async {}
}
