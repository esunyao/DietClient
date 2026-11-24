import 'client.dart';

/// 非 Web 平台不支持浏览器弹窗授权，调用时直接返回平台不支持失败。
Future<OidcSession> signInWithPopup(OidcClient client) => Future.error(
  const OidcFailure(
    'unsupported_platform',
    'Browser popup authorization is only available on Web.',
  ),
);
