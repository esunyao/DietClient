import 'dart:async';
import 'dart:convert';

import 'package:diet_oidc/diet_oidc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/auth_config.dart';

/// 表示启动恢复、未登录、会话可用或需要用户重试的状态。
enum SessionStatus { booting, signedOut, ready, retryRequired }

class SessionNotice extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final sessionNoticeProvider = NotifierProvider<SessionNotice, String?>(
  SessionNotice.new,
);

class SessionStatusController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() =>
      kIsWeb ? SessionStatus.signedOut : SessionStatus.booting;
  void set(SessionStatus value) => state = value;
}

/// 登录和清除会话时推进代次，用于隔离旧账户异步结果；普通续期不推进。
class SessionEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void advance() => state++;
}

final sessionEpochProvider = NotifierProvider<SessionEpoch, int>(
  SessionEpoch.new,
);
final sessionStatusProvider =
    NotifierProvider<SessionStatusController, SessionStatus>(
      SessionStatusController.new,
    );
final sessionProvider = NotifierProvider<SessionController, OidcSession?>(
  SessionController.new,
);

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// 用系统安全存储保存恢复记录；普通偏好中的禁用标记用于阻止读取旧记录。
class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();
  static const _storage = FlutterSecureStorage();
  static const _key = 'diet.refresh.v1';
  static const _disabledKey = 'diet.refresh.disabled';
  @override
  Future<String?> read() async =>
      await SharedPreferencesAsync().getBool(_disabledKey) == true
      ? null
      : _storage.read(key: _key);
  @override
  Future<void> write(String value) async {
    await _storage.write(key: _key, value: value);
    await SharedPreferencesAsync().setBool(_disabledKey, false);
  }

  @override
  Future<void> delete() async {
    try {
      await SharedPreferencesAsync().setBool(_disabledKey, true);
    } finally {
      await _storage.delete(key: _key);
    }
  }
}

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => const SecureSessionStorage(),
);
typedef RefreshSession = Future<OidcSession> Function(OidcSession session);
/// 使用当前认证配置创建 OIDC 客户端续期，并在请求结束后释放客户端。
final refreshSessionProvider = Provider<RefreshSession>(
  (ref) => (session) async {
    final config = ref.read(authConfigProvider).authentik;
    if (config == null) throw const OidcFailure('invalid_config', '登录配置不可用');
    final client = OidcClient(
      OidcConfig(
        discoveryUri: config.discoveryUri,
        clientId: config.clientId,
        redirectUri: config.redirectUri,
        scopes: config.scopes,
      ),
    );
    try {
      return await client.refresh(session);
    } finally {
      client.dispose();
    }
  },
);

/// Token rotation keeps the same epoch; login and logout advance it.
class SessionController extends Notifier<OidcSession?> {
  Timer? _expiry;
  bool _remember = false;
  Future<String>? _refresh;
  Future<void> _storageWork = Future.value();
  Future<void>? _restoring;
  int get epoch => ref.read(sessionEpochProvider);
  @override
  OidcSession? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  // 串行执行存储写入和删除；单次失败仍向调用方报告，但不阻断后续操作。
  Future<void> _store(Future<void> Function(SessionStorage) action) {
    final storage = ref.read(sessionStorageProvider);
    final next = _storageWork.then((_) => action(storage));
    _storageWork = next.catchError((Object _) {});
    return next;
  }

  void _status(SessionStatus value) =>
      ref.read(sessionStatusProvider.notifier).set(value);
  void _notice(String? value) =>
      ref.read(sessionNoticeProvider.notifier).set(value);
  void _advance() {
    ref.read(sessionEpochProvider.notifier).advance();
    _refresh = null;
  }

  /// 建立内存会话并推进代次；仅非 Web 且具备刷新令牌和身份时可记住登录。
  /// 保存失败只提示并尝试清理记录，不回退到明文存储。
  Future<void> establish(OidcSession session, {bool rememberMe = false}) async {
    _expiry?.cancel();
    _advance();
    final start = epoch;
    if (!hasActiveSession(session)) {
      await clear();
      return;
    }
    _remember =
        !kIsWeb &&
        rememberMe &&
        session.refreshToken?.isNotEmpty == true &&
        session.identity != null;
    state = session;
    _status(SessionStatus.ready);
    _arm(session);
    _notice(session.refreshToken == null ? '身份服务未提供续期凭据，过期后需要重新登录' : null);
    if (!kIsWeb) {
      final payload = _remember ? _encode(session) : null;
      try {
        await _store(
          (storage) =>
              payload == null ? storage.delete() : storage.write(payload),
        );
      } catch (_) {
        if (!ref.mounted || epoch != start) return;
        if (ref.mounted) {
          _remember = false;
          _notice('无法记住登录，本次会话仍可使用');
        }
        try {
          await _store((storage) => storage.delete());
        } catch (_) {
          /* Disabled marker prevents restoring stale credentials. */
        }
      }
    }
  }

  /// 合并并发恢复；非 Web 从安全存储读取记录，并通过强制续期验证后进入可用状态。
  Future<void> restore() =>
      _restoring ??= _restore().whenComplete(() => _restoring = null);
  Future<void> _restore() async {
    if (kIsWeb) return;
    final start = epoch;
    _status(SessionStatus.booting);
    try {
      final raw = await ref.read(sessionStorageProvider).read();
      if (!ref.mounted || epoch != start) return;
      if (raw == null) {
        _status(SessionStatus.signedOut);
        return;
      }
      // 恢复记录须匹配当前环境；先构造过期会话，让续期流程核对返回的身份。
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['environment'] != _environment) throw const FormatException();
      final identity = OidcIdentity(
        issuer: json['issuer'] as String,
        subject: json['subject'] as String,
        clientId: json['clientId'] as String,
        nonce: json['nonce'] as String?,
        authTime: json['authTime'] as int?,
        audience: List<String>.from(json['audience'] as List? ?? []),
        authorizedParty: json['authorizedParty'] as String?,
      );
      final refresh = json['refreshToken'] as String;
      if (refresh.isEmpty || identity.subject.isEmpty) {
        throw const FormatException();
      }
      _remember = true;
      state = OidcSession(
        accessToken: '',
        tokenType: 'Bearer',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        refreshToken: refresh,
        identity: identity,
      );
      await ensureFreshAccessToken(force: true);
    // 格式或类型无效时清理；其他恢复失败保留重试状态，旧代次不更新状态。
    } on FormatException {
      await clear();
    } on TypeError {
      await clear();
    } catch (_) {
      if (ref.mounted && epoch == start) _status(SessionStatus.retryRequired);
    }
  }

  /// 返回仍可用的访问令牌，或合并同一代次的续期请求；缺少续期条件时清除会话。
  Future<String> ensureFreshAccessToken({bool force = false}) {
    final current = state;
    if (current == null) {
      return Future.error(const OidcFailure('signed_out', '请重新登录'));
    }
    final canRefresh =
        !kIsWeb &&
        current.refreshToken?.isNotEmpty == true &&
        current.identity != null;
    if (!force &&
        (!canRefresh
            ? hasActiveSession(current)
            : current.expiresAt.isAfter(
                DateTime.now().add(const Duration(seconds: 30)),
              ))) {
      return Future.value(current.accessToken);
    }
    if (_refresh != null) return _refresh!;
    if (kIsWeb ||
        current.refreshToken?.isNotEmpty != true ||
        current.identity == null) {
      unawaited(clear());
      return Future.error(const OidcFailure('signed_out', '请重新登录'));
    }
    final start = epoch;
    final pending = _renew(current, start);
    _refresh = pending;
    unawaited(
      pending.then<void>(
        (_) {
          if (ref.mounted && epoch == start) _refresh = null;
        },
        onError: (Object _, StackTrace stack) {
          if (ref.mounted && epoch == start) _refresh = null;
        },
      ),
    );
    return pending;
  }

  // 续期后核对主体、签发方和客户端；代次变化或销毁时拒绝旧结果回写。
  // 按需尝试持久化轮换后的记录，再次检查代次后更新内存会话。
  Future<String> _renew(OidcSession current, int start) async {
    try {
      final fresh = await ref.read(refreshSessionProvider)(current);
      if (!ref.mounted || epoch != start) {
        throw const OidcFailure('cancelled', '会话已更换');
      }
      if (!hasActiveSession(fresh) ||
          fresh.identity?.subject != current.identity?.subject ||
          fresh.identity?.issuer != current.identity?.issuer ||
          fresh.identity?.clientId != current.identity?.clientId) {
        throw const OidcFailure('invalid_claims', '会话身份不匹配');
      }
      _notice(null);
      if (_remember) {
        try {
          await _store((storage) => storage.write(_encode(fresh)));
        } catch (_) {
          if (!ref.mounted || epoch != start) {
            throw const OidcFailure('cancelled', '会话已更换');
          }
          _remember = false;
          _notice('无法记住登录，本次会话仍可使用');
          try {
            await _store((storage) => storage.delete());
          } catch (_) {
            /* See disabled marker. */
          }
        }
      }
      if (!ref.mounted || epoch != start) {
        throw const OidcFailure('cancelled', '会话已更换');
      }
      state = fresh;
      _status(SessionStatus.ready);
      _arm(fresh);
      return fresh.accessToken;
    // 凭据或身份类失败清除会话；其他失败保留可用会话或切换为待重试。
    } catch (e) {
      if (ref.mounted && epoch == start) {
        if (e is OidcFailure &&
            const [
              'refresh_rejected',
              'invalid_claims',
              'invalid_refresh_context',
              'invalid_token',
              'invalid_metadata',
              'invalid_response',
              'untrusted_endpoint',
            ].contains(e.code)) {
          await clear();
        } else {
          _status(
            hasActiveSession(state)
                ? SessionStatus.ready
                : SessionStatus.retryRequired,
          );
          _notice('暂时无法续期，请检查网络后重试');
          // A failed early refresh must still enforce the old token's expiry.
          _expiry?.cancel();
          if (hasActiveSession(state)) {
            _expiry = Timer(state!.expiresAt.difference(DateTime.now()), () {
              if (ref.mounted && epoch == start) {
                _status(SessionStatus.retryRequired);
                unawaited(
                  ensureFreshAccessToken(force: true).then<void>(
                    (_) {},
                    onError: (Object _, StackTrace stack) {},
                  ),
                );
              }
            });
          }
        }
      }
      rethrow;
    }
  }

  // 非 Web 且刷新令牌非 null 时提前触发：剩余寿命的五分之一，最多 60 秒。
  // 其他情况到期清除；重新安排或控制器销毁时取消旧定时器。
  void _arm(OidcSession session) {
    _expiry?.cancel();
    final lifetime = session.expiresAt.difference(DateTime.now());
    final lead = !kIsWeb && session.refreshToken != null
        ? Duration(milliseconds: (lifetime.inMilliseconds ~/ 5).clamp(0, 60000))
        : Duration.zero;
    _expiry = Timer(lifetime - lead, () {
      if (kIsWeb || session.refreshToken == null) {
        unawaited(clear());
      } else {
        unawaited(
          ensureFreshAccessToken(force: true)
              .then<void>((_) {}, onError: (Object _, StackTrace stack) {}),
        );
      }
    });
  }

  /// 检查已过期的内存会话，并异步尝试续期或清除。
  void checkExpiry() {
    if (state != null && !hasActiveSession(state)) {
      unawaited(
        ensureFreshAccessToken().then<void>(
          (_) {},
          onError: (Object _, StackTrace stack) {},
        ),
      );
    }
  }

  /// 先推进代次并清空内存状态，再尝试删除本机恢复记录；不执行全局 SSO 注销。
  Future<void> clear() async {
    _expiry?.cancel();
    _expiry = null;
    _remember = false;
    _advance();
    state = null;
    _status(SessionStatus.signedOut);
    _notice(null);
    if (!kIsWeb) {
      try {
        await _store((storage) => storage.delete());
      } catch (_) {
        if (ref.mounted) _notice('本机登录记录清理失败，请检查系统安全存储');
      }
    }
  }

  // 恢复记录绑定 API 地址与身份配置，只编码刷新令牌和身份校验上下文。
  String get _environment => jsonEncode([
    const String.fromEnvironment('API_BASE_URL'),
    ref.read(authConfigProvider).authentik?.discoveryUri.toString(),
    ref.read(authConfigProvider).authentik?.clientId,
  ]);
  String _encode(OidcSession session) => jsonEncode({
    'environment': _environment,
    'refreshToken': session.refreshToken,
    'issuer': session.identity!.issuer,
    'subject': session.identity!.subject,
    'clientId': session.identity!.clientId,
    'nonce': session.identity!.nonce,
    'authTime': session.identity!.authTime,
    'audience': session.identity!.audience,
    'authorizedParty': session.identity!.authorizedParty,
  });
}

bool hasActiveSession(OidcSession? session, {DateTime? now}) =>
    session != null && session.expiresAt.isAfter(now ?? DateTime.now());
