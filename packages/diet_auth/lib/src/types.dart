class AuthentikConfig {
  AuthentikConfig({
    required this.baseUri,
    required this.providerSlug,
    required this.authenticationFlowSlug,
    required this.clientId,
    required this.redirectUri,
    required this.webRedirectUri,
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
