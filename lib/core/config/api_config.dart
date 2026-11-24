/// 业务 API 基址配置，校验协议与回环规则并补齐末尾斜杠。
class ApiConfig {
  /// 从配置字符串解析业务基址；无效地址或非回环明文 HTTP 时抛出 [FormatException]。
  ApiConfig(String value) : baseUrl = _parse(value);

  final Uri baseUrl;

  static Uri _parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.endsWith('.invalid') ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme == 'http' &&
            !['localhost', '127.0.0.1', '::1'].contains(uri.host))) {
      throw const FormatException('请配置有效的 API_BASE_URL');
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }
}
