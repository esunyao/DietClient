import 'dart:convert';

/// 无损解码业务 API 返回的 JSON 文本；在解码前将长整型业务 ID 转为字符串以避免精度丢失。
Object? decodeApiJson(String raw) {
  const keys = {
    'measurementId',
    'goalId',
    'allergyId',
    'conditionId',
    'restrictionId',
    'consentId',
    'mealId',
    'itemId',
    'imageId',
  };
  final out = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    if (raw[i] != '"') {
      out.write(raw[i++]);
      continue;
    }
    final start = i++;
    while (i < raw.length) {
      if (raw.codeUnitAt(i) == 92) {
        i += 2;
        continue;
      }
      if (raw[i++] == '"') break;
    }
    final token = raw.substring(start, i);
    out.write(token);
    var cursor = i;
    while (cursor < raw.length && raw[cursor].trim().isEmpty) {
      cursor++;
    }
    if (!keys.contains(jsonDecode(token)) ||
        cursor >= raw.length ||
        raw[cursor] != ':') {
      continue;
    }
    cursor++;
    while (cursor < raw.length && raw[cursor].trim().isEmpty) {
      cursor++;
    }
    // 仅将指定键下完整的整数值改写为 JSON 字符串，避免解码时丢失长 ID 精度。
    // 其他值保持原样，最终仍由标准 JSON 解码器校验。
    final match = RegExp(r'^-?\d+(?=\s*[,}\]])')
        .firstMatch(raw.substring(cursor));
    if (match != null) {
      out.write(raw.substring(i, cursor));
      out.write(jsonEncode(match.group(0)));
      i = cursor + match.group(0)!.length;
    }
  }
  return jsonDecode(out.toString());
}
