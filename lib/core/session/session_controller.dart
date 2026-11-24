import 'dart:async';
import 'dart:convert';

import 'package:diet_oidc/diet_oidc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/auth_config.dart';

/// 会话生命周期状态：启动恢复中、未登录、已就绪、需重试恢复。
enum SessionStatus { booting, signedOut, ready, retryRequired }

/// 会话提示信息控制器，用于向页面外壳投递非阻塞提醒。
class SessionNotice extends Notifier<String?> {
  @override
  String? build() => null;

  /// 更新当前会话提示文案；传 `null` 清除提示。
  void set(String? value) => state = value;
}

/// 全局会话提示 Provider。
final sessionNoticeProvider = NotifierProvider<SessionNotice, String?>(
  SessionNotice.new,
);

/// 会话门控状态控制器。
class SessionStatusController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() =>
      kIsWeb ? SessionStatus.signedOut : SessionStatus.booting;

  /// 更新当前会话门控状态。
  void set(SessionStatus value) => state = value;
}

/// 登录代次计数器；登录与退出时递增以隔离旧账户异步结果，普通续期不改变代次。
class SessionEpoch extends Notifier<int> {
  @override
  int build() => 0;

  /// 推进登录代次。
  void advance() => state++;
}

/// 全局登录代次 Provider。
final sessionEpochProvider = NotifierProvider<SessionEpoch, int>(
  SessionEpoch.new,
);

/// 全局会话门控状态 Provider。
final sessionStatusProvider =
    NotifierProvider<SessionStatusController, SessionStatus>(
      SessionStatusController.new,
    );

/// 全局内存登录会话 Provider。
final sessionProvider = NotifierProvider<SessionController, OidcSession?>(
  SessionController.new,
);

/// 本机记住登录存储抽象接口（供测试替换安全存储）。
abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// 基于系统安全存储的会话存储实现；配合禁用标记防止读取已清除的旧凭据。
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

/// 全局记住登录存储 Provider。
final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => const SecureSessionStorage(),
);

/// 会话刷新回调签名。
typedef RefreshSession = Future<OidcSession> Function(OidcSession session);

/// OIDC 会话续期函数 Provider；使用当前认证配置执行刷新并释放临时客户端。
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

/// 核心 OIDC 会话生命周期、续期与可选记住登录控制器；普通续期不推进代次。
class SessionController extends Notifier<OidcSession?> {
  Timer? _expiry;
  bool _remember = false;
  Future<String>? _refresh;
  Future<void> _storageWork = Future.value();
  Future<void>? _restoring;

  /// 当前登录代次。
  int get epoch => ref.read(sessionEpochProvider);

  /// 判断控制器是否仍挂载且登录代次与 [value] 一致。
  bool isCurrentEpoch(int value) => ref.mounted && epoch == value;

  @override
  OidcSession? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  /// 串行调度安全存储写入与删除操作；单次失败向调用方报错但不阻断后续队列。
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

  /// 建立内存会话并推进登录代次；仅非 Web 且具备刷新令牌和身份时写入安全存储。
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
          // 禁用标记已阻止读取失效凭据。
        }
      }
    }
  }

  /// 若当前处于启动恢复阶段，则异步触发本机恢复流程。
  void restoreIfBooting() {
    if (ref.read(sessionStatusProvider) == SessionStatus.booting) {
      unawaited(restore());
    }
  }

  /// 尝试从安全存储恢复已记住的会话；并发调用会合并到同一恢复 Future。
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

  /// 获取当前可用的访问令牌，临近过期或 [force] 为 `true` 时触发续期；并发请求自动合并。
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

  /// 执行令牌续期并校验主体、签发方、客户端与代次一致性；身份失败时抛出 [OidcFailure]。
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
            // 禁用标记已阻止后续恢复读取旧凭据。
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
          // 提前续期失败后仍须按旧令牌剩余有效期执行过期兜底。
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

  /// 为当前活动会话安排到期自动续期或过期清除定时器。
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

  /// 检查当前内存会话是否已过期，必要时异步触发续期或清除。
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

  /// 清除当前应用内存会话及本机记住登录记录，不注销全局 SSO。
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

  /// 计算绑定 API 地址与身份配置的环境指纹，防止跨环境恢复旧会话记录。
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

/// 判断给定 [session] 是否处于未过期可用状态。
bool hasActiveSession(OidcSession? session, {DateTime? now}) =>
    session != null && session.expiresAt.isAfter(now ?? DateTime.now());
