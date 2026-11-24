/// Authentik OIDC 与 Flow Executor 公开配置，校验源地址、slug 与客户端标识合法性。
class AuthentikConfig {
  AuthentikConfig({
    required this.baseUri,
    required this.providerSlug,
    required this.authenticationFlowSlug,
    required this.clientId,
    required this.redirectUri,
    required this.webRedirectUri,
    this.enrollmentFlowSlug,
    this.emailVerificationResendFlowSlug,
    this.scopes = const ['openid', 'profile', 'email'],
  }) {
    final loopback = const [
      'localhost',
      '127.0.0.1',
      '::1',
    ].contains(baseUri.host);
    if (!(baseUri.scheme == 'https' ||
            (baseUri.scheme == 'http' && loopback)) ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        (baseUri.path.isNotEmpty && baseUri.path != '/') ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(providerSlug) ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(authenticationFlowSlug) ||
        clientId.trim().isEmpty) {
      throw const AuthFailure('configuration', '登录配置无效。');
    }
  }

  final String? enrollmentFlowSlug;
  final String? emailVerificationResendFlowSlug;
  final Uri baseUri;
  final String providerSlug;
  final String authenticationFlowSlug;
  final String clientId;
  final Uri redirectUri;
  final Uri webRedirectUri;
  final List<String> scopes;

  /// 根据当前配置拼装标准的 OIDC discovery 文档地址。
  Uri get discoveryUri => baseUri.resolve(
    '/application/o/$providerSlug/.well-known/openid-configuration',
  );
}

/// 认证同意阶段展示的应用标题与权限说明列表。
class AuthentikConsent {
  AuthentikConsent({required this.title, required List<String> permissions})
    : permissions = List.unmodifiable(permissions);

  final String title;
  final List<String> permissions;
}

/// Authentik 认证或辅助流程失败异常，对外仅暴露安全提示。
class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}

/// 包含逐字段校验错误映射的认证失败异常；仅暴露字段提示，不暴露 Cookie 或协议数据。
class AuthFieldFailure extends AuthFailure {
  AuthFieldFailure(Map<String, String> errors)
    : fields = Map.unmodifiable(errors),
      super('field_error', '请检查表单中的提示后重试。');
  final Map<String, String> fields;
}
