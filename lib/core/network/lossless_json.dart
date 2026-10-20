import 'dart:convert';

/// 在 JSON 解码之前保护业务 ID，跳过字符串内部的转义内容。
Object? decodeApiJson(String raw) {
  const keys = {
    'measurementId',
    'goalId',
    'allergyId',
    'conditionId',
    'restrictionId',
    'consentId',
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
