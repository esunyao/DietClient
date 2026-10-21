import 'package:diet_auth/diet_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 只读取编译期公开参数，不读文件，不接收 client secret。
class AppAuthConfig {
  AppAuthConfig.fromValues(
    Map<String, String> values, {
    bool web = false,
    Uri? origin,
  }) {
    String requiredValue(String key) {
      final value = values[key]?.trim() ?? '';
      if (value.isEmpty) issues.add('缺少 $key');
      return value;
    }

    Uri? parseUri(
      String key, {
      bool https = false,
      bool allowLoopback = false,
    }) {
      final value = requiredValue(key);
      if (value.isEmpty) return null;
      final uri = Uri.tryParse(value);
      final local = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
      if (uri == null ||
          !uri.hasScheme ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (https &&
              (uri.host.isEmpty ||
                  (uri.scheme != 'https' &&
                      !(allowLoopback && local && uri.scheme == 'http')))) ||
          uri.host.endsWith('.invalid')) {
        issues.add('$key 无效或仍为示例占位符');
        return null;
      }
      return uri;
    }

    final base = parseUri('AUTHENTIK_BASE_URL', https: true);
    if (base != null &&
        (base.hasQuery || (base.path.isNotEmpty && base.path != '/'))) {
      issues.add('AUTHENTIK_BASE_URL 只能包含服务源地址');
    }
    final provider = requiredValue('AUTHENTIK_PROVIDER_SLUG');
    final flow = requiredValue('AUTHENTIK_AUTHENTICATION_FLOW_SLUG');
    final client = requiredValue('AUTHENTIK_CLIENT_ID');
    final redirect = parseUri('AUTHENTIK_REDIRECT_URI');
    final webRedirect = parseUri(
      'AUTHENTIK_WEB_REDIRECT_URI',
      https: true,
      allowLoopback: true,
    );
    final scopes = requiredValue('AUTHENTIK_SCOPES')
        .split(RegExp(r'\s+'))
        .where((v) => v.isNotEmpty)
        .toList();
    if (!scopes.contains('openid')) issues.add('AUTHENTIK_SCOPES 必须包含 openid');
    for (final entry in {
      'AUTHENTIK_PROVIDER_SLUG': provider,
      'AUTHENTIK_AUTHENTICATION_FLOW_SLUG': flow,
    }.entries) {
      if (entry.value.isNotEmpty &&
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(entry.value)) {
        issues.add('${entry.key} 格式无效');
      }
    }
    if (web &&
        webRedirect != null &&
        origin != null &&
        (origin.scheme != webRedirect.scheme ||
            origin.host != webRedirect.host ||
            origin.port != webRedirect.port)) {
      issues.add('AUTHENTIK_WEB_REDIRECT_URI 必须与当前页面同源');
    }
    if (issues.isEmpty) {
      try {
        authentik = AuthentikConfig(
          baseUri: base!,
          enrollmentFlowSlug: values['AUTHENTIK_ENROLLMENT_FLOW_SLUG']?.trim(),
          emailVerificationResendFlowSlug:
              values['AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG']?.trim(),
          providerSlug: provider,
          authenticationFlowSlug: flow,
          clientId: client,
          redirectUri: redirect!,
          webRedirectUri: webRedirect!,
          scopes: scopes,
        );
      } on AuthFailure {
        issues.add('身份服务配置格式无效，请检查公开参数');
      }
    }
  }

  factory AppAuthConfig.fromEnvironment() => AppAuthConfig.fromValues(
    const {
      'AUTHENTIK_BASE_URL': String.fromEnvironment('AUTHENTIK_BASE_URL'),
      'AUTHENTIK_PROVIDER_SLUG': String.fromEnvironment(
        'AUTHENTIK_PROVIDER_SLUG',
      ),
      'AUTHENTIK_AUTHENTICATION_FLOW_SLUG': String.fromEnvironment(
        'AUTHENTIK_AUTHENTICATION_FLOW_SLUG',
      ),
      'AUTHENTIK_ENROLLMENT_FLOW_SLUG': String.fromEnvironment(
        'AUTHENTIK_ENROLLMENT_FLOW_SLUG',
      ),
      'AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG': String.fromEnvironment(
        'AUTHENTIK_EMAIL_VERIFICATION_RESEND_FLOW_SLUG',
      ),
      'AUTHENTIK_CLIENT_ID': String.fromEnvironment('AUTHENTIK_CLIENT_ID'),
      'AUTHENTIK_REDIRECT_URI': String.fromEnvironment(
        'AUTHENTIK_REDIRECT_URI',
      ),
      'AUTHENTIK_WEB_REDIRECT_URI': String.fromEnvironment(
        'AUTHENTIK_WEB_REDIRECT_URI',
      ),
      'AUTHENTIK_SCOPES': String.fromEnvironment('AUTHENTIK_SCOPES'),
    },
    web: kIsWeb,
    origin: kIsWeb ? Uri.base : null,
  );

  final List<String> issues = [];
  AuthentikConfig? authentik;
  bool get isReady => authentik != null;
  @override
  String toString() => 'AppAuthConfig(ready: $isReady)';
}

final authConfigProvider = Provider<AppAuthConfig>(
  (ref) => AppAuthConfig.fromEnvironment(),
);
