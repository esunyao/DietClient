import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/privacy/ai_consent.dart';
import '../data/profile_api.dart';

final profileApiProvider = Provider<ProfileApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  final api = ProfileApi(client);
  ref.onDispose(api.close);
  return api;
});

/// PATCH 返回值是当前已确认档案，手动刷新时清除后重新 GET。
final confirmedProfileProvider = NotifierProvider<ConfirmedProfile, Json?>(
  ConfirmedProfile.new,
);

class ConfirmedProfile extends Notifier<Json?> {
  @override
  Json? build() {
    ref.watch(sessionEpochProvider);
    return null;
  }

  bool accept(Json value, Object? session) {
    if (!ref.mounted || ref.read(sessionEpochProvider) != session) {
      return false;
    }
    state = Map<String, dynamic>.unmodifiable(value);
    return true;
  }

  void clear() => state = null;
}

final profileProvider = FutureProvider<Json>((ref) async {
  ref.watch(sessionEpochProvider);
  final confirmed = ref.watch(confirmedProfileProvider);
  if (confirmed != null) return confirmed;
  return await ref.watch(profileApiProvider)?.profile() ?? {};
});
final healthRecordsProvider = FutureProvider.family<List<Json>, String>(
  (ref, kind) async => await ref.watch(profileApiProvider)?.list(kind) ?? [],
);
final consentsProvider = consentRecordsProvider;
