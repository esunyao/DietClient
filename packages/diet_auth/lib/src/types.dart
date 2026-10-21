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

  Uri get discoveryUri => baseUri.resolve(
    '/application/o/$providerSlug/.well-known/openid-configuration',
  );
}

class AuthentikConsent {
  AuthentikConsent({required this.title, required List<String> permissions})
    : permissions = List.unmodifiable(permissions);

  final String title;
  final List<String> permissions;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}

/// Only field validation errors are exposed; cookies and protocol data stay private.
class AuthFieldFailure extends AuthFailure {
  AuthFieldFailure(Map<String, String> errors)
    : fields = Map.unmodifiable(errors),
      super('field_error', '请检查表单中的提示后重试。');
  final Map<String, String> fields;
}
