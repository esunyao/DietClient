import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:openid_client/openid_client.dart' as oidc;

import 'popup_stub.dart' if (dart.library.js_interop) 'popup_web.dart' as popup;

final class OidcConfig {
  final Uri discoveryUri;
  final String clientId;
  final Uri redirectUri;
  final List<String> scopes;

  OidcConfig({
    required this.discoveryUri,
    required this.clientId,
    required this.redirectUri,
    List<String> scopes = const ['openid', 'profile', 'email'],
  }) : scopes = List.unmodifiable(scopes) {
    if (!_https(discoveryUri) ||
        clientId.trim().isEmpty ||
        !scopes.contains('openid') ||
        redirectUri.hasQuery ||
        redirectUri.hasFragment ||
        redirectUri.userInfo.isNotEmpty ||
        redirectUri.scheme.isEmpty) {
      throw const OidcFailure(
        'invalid_config',
        'Invalid public OIDC configuration.',
      );
    }
  }
}

final class OidcFailure implements Exception {
  final String code;
  final String message;
  const OidcFailure(this.code, this.message);
  @override
  String toString() => 'OidcFailure($code): $message';
}

/// Identity established by a verified ID token.
final class OidcIdentity {
  const OidcIdentity({
    required this.issuer,
    required this.subject,
    required this.clientId,
    this.nonce,
    this.authTime,
    this.audience = const [],
    this.authorizedParty,
  });
  final String issuer;
  final String subject;
  final String clientId;
  final String? nonce;
  final int? authTime;
  final List<String> audience;
  final String? authorizedParty;
  @override
  String toString() => 'OidcIdentity([redacted])';
}

final class OidcSession {
  final String accessToken;
  final String tokenType;
  final String? idToken;
  final DateTime expiresAt;
  final String? refreshToken;
  final OidcIdentity? identity;
  const OidcSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    this.idToken,
    this.refreshToken,
    this.identity,
  });
  @override
  String toString() =>
      'OidcSession(tokenType: $tokenType, expiresAt: $expiresAt, tokens: [redacted])';
}

final class OidcTransaction {
  final oidc.Flow _flow;
  final String _nonce;
  final String _codeVerifier;
  final Completer<void> _cancellation = Completer<void>();
  final DateTime _createdAt = DateTime.now();
  bool _used = false;
  void Function()? _cancelPopup;
  OidcTransaction._(this._flow, this._nonce, this._codeVerifier);
  Uri get authorizationUri => _flow.authenticationUri;
  String get state => _flow.state;
  Uri get redirectUri => _flow.redirectUri;
  @override
  String toString() => 'OidcTransaction([redacted])';
}

final class OidcClient {
  final OidcConfig config;
  final http.Client _baseClient;
  late final http.Client _http = _RestrictedClient(
    _baseClient,
    config.discoveryUri,
  );
  final bool _ownsClient;
  final Set<OidcTransaction> _transactions = {};
  final Set<void Function()> _popupCancellations = {};
  bool _disposed = false;
  int _generation = 0;
  Completer<void> _pendingCancellation = Completer<void>();

  OidcClient(this.config, {http.Client? httpClient})
    : _baseClient = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  Future<OidcTransaction> beginAuthorization() async {
    _checkAlive();
    final generation = _generation;
    final cancelled = _pendingCancellation.future;
    try {
      final response = await _request(
        _http.get(config.discoveryUri),
        cancelled,
      );
      _checkAlive();
      if (generation != _generation) {
        throw const OidcFailure('cancelled', 'Authorization was cancelled.');
      }
      final metadata = oidc.OpenIdProviderMetadata.fromJson(_json(response));
      final endpoints = [
        metadata.issuer,
        metadata.authorizationEndpoint,
        metadata.tokenEndpoint,
        metadata.jwksUri,
      ];
      if (endpoints.any(
            (u) =>
                u == null || !_https(u) || !_sameOrigin(u, config.discoveryUri),
          ) ||
          !metadata.responseTypesSupported.contains('code')) {
        throw const OidcFailure(
          'invalid_metadata',
          'Provider metadata is not trusted.',
        );
      }
      final algorithms = metadata.idTokenSigningAlgValuesSupported;
      if (!algorithms.any(_safeAlgorithm)) {
        throw const OidcFailure(
          'invalid_metadata',
          'Provider has no supported signing algorithm.',
        );
      }
      final client = oidc.Client(
        oidc.Issuer(metadata),
        config.clientId,
        httpClient: _http,
      );
      final nonce = _random();
      final verifier = _random();
      final flow = oidc.Flow.authorizationCodeWithPKCE(
        client,
        codeVerifier: verifier,
        scopes: config.scopes,
        additionalParameters: {'nonce': nonce},
      );
      flow.redirectUri = config.redirectUri;
      // The library filters scopes against metadata; explicit requested scopes
      // remain valid even when optional scopes_supported is absent.
      flow.scopes
        ..clear()
        ..addAll(config.scopes);
      _checkAlive();
      final tx = OidcTransaction._(flow, nonce, verifier);
      _transactions.add(tx);
      return tx;
    } on OidcFailure {
      rethrow;
    } catch (_) {
      throw const OidcFailure(
        'discovery_failed',
        'Unable to load OIDC provider metadata.',
      );
    }
  }

  Future<OidcSession> completeAuthorization(
    OidcTransaction tx,
    Uri callbackUri,
  ) async {
    _checkAlive();
    if (!_transactions.contains(tx) || tx._used) {
      throw const OidcFailure(
        'invalid_transaction',
        'Authorization transaction is no longer active.',
      );
    }
    if (DateTime.now().difference(tx._createdAt) > const Duration(minutes: 5)) {
      cancel(tx);
      throw const OidcFailure('timeout', 'Authorization timed out.');
    }
    try {
      if (!_sameCallback(callbackUri, tx.redirectUri) ||
          callbackUri.hasFragment) {
        throw const OidcFailure(
          'invalid_callback',
          'Unexpected authorization callback.',
        );
      }
      final parameters = callbackUri.queryParametersAll;
      if (parameters.values.any((values) => values.length != 1) ||
          parameters['state']?.single != tx.state) {
        throw const OidcFailure(
          'state_mismatch',
          'Authorization state did not match.',
        );
      }
      // Consume before the token request, including provider rejection.
      tx._used = true;
      final error = parameters['error']?.single;
      if (error != null) {
        throw const OidcFailure(
          'authorization_denied',
          'The provider declined authorization.',
        );
      }
      final code = parameters['code']?.single;
      if (code == null ||
          code.isEmpty ||
          parameters.containsKey('access_token') ||
          parameters.containsKey('id_token')) {
        throw const OidcFailure(
          'invalid_callback',
          'Authorization code is missing or invalid.',
        );
      }
      final metadata = tx._flow.client.issuer.metadata;
      // openid_client's callback logs raw token response bodies at Fine level.
      // Keep its standard PKCE flow/model, but use our controlled HTTP exchange.
      final tokenResponse = await _request(
        _http.post(
          metadata.tokenEndpoint!,
          body: {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': tx.redirectUri.toString(),
            'client_id': config.clientId,
            'code_verifier': tx._codeVerifier,
          },
        ),
        tx._cancellation.future,
      );
      final tokenReceivedAt = DateTime.now().toUtc();
      final response = oidc.TokenResponse.fromJson(_json(tokenResponse))
          .toJson();
      final rawId = response['id_token'];
      final accessToken = response['access_token'];
      final tokenType = response['token_type'];
      if (rawId is! String ||
          rawId.isEmpty ||
          accessToken is! String ||
          accessToken.isEmpty ||
          tokenType is! String ||
          tokenType.toLowerCase() != 'bearer') {
        throw const OidcFailure(
          'invalid_token',
          'Provider returned an incomplete token response.',
        );
      }
      final token = oidc.IdToken.unverified(rawId);
      final keyResponse = await _request(
        _http.get(metadata.jwksUri!),
        tx._cancellation.future,
      );
      final keyStore = JsonWebKeyStore()
        ..addKeySet(JsonWebKeySet.fromJson(_json(keyResponse)));
      final allowed = metadata.idTokenSigningAlgValuesSupported
          .where(_safeAlgorithm)
          .toList();
      if (!await token.verify(keyStore, allowedArguments: allowed)) {
        throw const OidcFailure(
          'invalid_signature',
          'ID token signature validation failed.',
        );
      }
      final claims = token.claims;
      final json = claims.toJson();
      if (json['iss'] is! String ||
          json['sub'] is! String ||
          (json['sub'] as String).isEmpty ||
          json['exp'] is! num ||
          json['iat'] is! num ||
          !(json['aud'] is String || json['aud'] is List)) {
        throw const OidcFailure(
          'invalid_claims',
          'ID token required claims are missing.',
        );
      }
      final errors = claims
          .validate(
            issuer: metadata.issuer,
            clientId: config.clientId,
            nonce: tx._nonce,
          )
          .toList();
      final now = DateTime.now().toUtc();
      if (errors.isNotEmpty ||
          claims.nonce != tx._nonce ||
          claims.issuedAt.isAfter(now.add(const Duration(seconds: 30))) ||
          (claims.notBefore != null && claims.notBefore!.isAfter(now))) {
        throw const OidcFailure(
          'invalid_claims',
          'ID token claims validation failed.',
        );
      }
      var expiresAt = claims.expiry.toUtc();
      final expiresIn = response['expires_in'];
      if (expiresIn != null) {
        final seconds = expiresIn is int
            ? expiresIn
            : int.tryParse(expiresIn.toString());
        if (seconds == null || seconds <= 0) {
          throw const OidcFailure('invalid_token', 'Token expiry is invalid.');
        }
        final expiry = tokenReceivedAt.add(Duration(seconds: seconds));
        if (expiry.isBefore(expiresAt)) expiresAt = expiry;
      }
      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const OidcFailure(
          'expired_token',
          'The returned session has expired.',
        );
      }
      _checkAlive();
      if (!_transactions.contains(tx)) {
        throw const OidcFailure('cancelled', 'Authorization was cancelled.');
      }
      return OidcSession(
        accessToken: accessToken,
        tokenType: tokenType,
        idToken: rawId,
        refreshToken: response['refresh_token'] as String?,
        identity: OidcIdentity(
          issuer: json['iss'] as String,
          subject: json['sub'] as String,
          clientId: config.clientId,
          nonce: tx._nonce,
          authTime: (json['auth_time'] as num?)?.toInt(),
          audience: json['aud'] is String
              ? [json['aud'] as String]
              : List<String>.from(json['aud'] as List),
          authorizedParty: json['azp'] as String?,
        ),
        expiresAt: expiresAt,
      );
    } on OidcFailure {
      rethrow;
    } catch (_) {
      throw const OidcFailure(
        'token_validation_failed',
        'Unable to verify the authorization response.',
      );
    } finally {
      cancel(tx);
    }
  }

  /// Refresh is bound to trusted discovery and the previously verified subject.
  Future<OidcSession> refresh(OidcSession previous) async {
    try {
      return await _refresh(previous);
    } on OidcFailure {
      rethrow;
    } catch (_) {
      throw const OidcFailure(
        'invalid_token',
        'Refresh response validation failed.',
      );
    }
  }

  Future<OidcSession> _refresh(OidcSession previous) async {
    _checkAlive();
    final identity = previous.identity;
    if (identity == null ||
        identity.clientId != config.clientId ||
        previous.refreshToken?.isNotEmpty != true) {
      throw const OidcFailure(
        'invalid_refresh_context',
        'Refresh identity is unavailable.',
      );
    }
    final cancelled = _pendingCancellation.future;
    final metadata = oidc.OpenIdProviderMetadata.fromJson(
      _json(await _request(_http.get(config.discoveryUri), cancelled)),
    );
    if (metadata.issuer.toString() != identity.issuer ||
        [metadata.issuer, metadata.tokenEndpoint, metadata.jwksUri].any(
          (u) =>
              u == null || !_https(u) || !_sameOrigin(u, config.discoveryUri),
        )) {
      throw const OidcFailure(
        'invalid_metadata',
        'Refresh provider is not trusted.',
      );
    }
    final result = await _request(
      _http.post(
        metadata.tokenEndpoint!,
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': previous.refreshToken!,
          'client_id': config.clientId,
        },
      ),
      cancelled,
    );
    final tokenReceivedAt = DateTime.now().toUtc();
    if (result.statusCode == 400 || result.statusCode == 401) {
      throw const OidcFailure(
        'refresh_rejected',
        'Refresh authorization was rejected.',
      );
    }
    final data = _json(result);
    final access = data['access_token'];
    final seconds = int.tryParse('${data['expires_in']}');
    if (access is! String ||
        access.isEmpty ||
        data['token_type'] is! String ||
        (data['token_type'] as String).toLowerCase() != 'bearer' ||
        seconds == null ||
        seconds <= 0 ||
        (data.containsKey('refresh_token') &&
            (data['refresh_token'] is! String ||
                (data['refresh_token'] as String).isEmpty))) {
      throw const OidcFailure('invalid_token', 'Invalid refresh response.');
    }
    final rawId = data['id_token'];
    if (rawId != null) {
      if (rawId is! String || rawId.isEmpty) {
        throw const OidcFailure('invalid_token', 'Invalid refreshed ID token.');
      }
      final token = oidc.IdToken.unverified(rawId);
      final keys = JsonWebKeyStore()
        ..addKeySet(
          JsonWebKeySet.fromJson(
            _json(await _request(_http.get(metadata.jwksUri!), cancelled)),
          ),
        );
      final claims = token.claims;
      final json = claims.toJson();
      final audiences = json['aud'] is String
          ? [json['aud'] as String]
          : json['aud'] is List
          ? List<String>.from(json['aud'] as List)
          : <String>[];
      if (!await token.verify(
            keys,
            allowedArguments: metadata.idTokenSigningAlgValuesSupported
                .where(_safeAlgorithm)
                .toList(),
          ) ||
          json['sub'] != identity.subject ||
          json['iss'] != identity.issuer ||
          json['exp'] is! num ||
          json['iat'] is! num ||
          (json['nonce'] != null && json['nonce'] != identity.nonce) ||
          (json.containsKey('auth_time') &&
              json['auth_time'] != identity.authTime) ||
          (identity.authorizedParty != json['azp']) ||
          (identity.audience.isNotEmpty &&
              (audiences.toSet().length != identity.audience.toSet().length ||
                  !audiences.toSet().containsAll(identity.audience.toSet()))) ||
          claims
              .validate(issuer: metadata.issuer, clientId: config.clientId)
              .isNotEmpty ||
          claims.issuedAt.isAfter(
            DateTime.now().toUtc().add(const Duration(seconds: 30)),
          ) ||
          (claims.notBefore != null &&
              claims.notBefore!.isAfter(DateTime.now().toUtc()))) {
        throw const OidcFailure(
          'invalid_claims',
          'Refreshed identity did not match.',
        );
      }
    }
    _checkAlive();
    return OidcSession(
      accessToken: access,
      tokenType: 'Bearer',
      expiresAt: tokenReceivedAt.add(Duration(seconds: seconds)),
      refreshToken: data['refresh_token'] as String? ?? previous.refreshToken,
      identity: identity,
      idToken: rawId as String?,
    );
  }

  // This method must remain non-async: the browser window is opened on the
  // initiating click stack, before discovery has a chance to await.
  Future<OidcSession> signInWithPopup() {
    _checkAlive();
    return popup.signInWithPopup(this);
  }

  void cancel(OidcTransaction tx) {
    _transactions.remove(tx);
    tx._used = true;
    if (!tx._cancellation.isCompleted) tx._cancellation.complete();
    tx._cancelPopup?.call();
    tx._cancelPopup = null;
  }

  /// Cancel active authorizations, including a popup still loading discovery.
  void cancelPending() {
    _generation++;
    _pendingCancellation.complete();
    _pendingCancellation = Completer<void>();
    for (final cancel in _popupCancellations.toList()) {
      cancel();
    }
    for (final tx in _transactions.toList()) {
      cancel(tx);
    }
  }

  /// Internal lifecycle hook used by the conditional browser bridge.
  void Function() registerPopupCancellation(void Function() onCancel) {
    _popupCancellations.add(onCancel);
    return () => _popupCancellations.remove(onCancel);
  }

  /// Bridge lifecycle hook; consumers should normally use [cancel].
  void attachPopupCancellation(OidcTransaction tx, void Function() onCancel) {
    if (!_transactions.contains(tx)) {
      onCancel();
    } else {
      tx._cancelPopup = onCancel;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelPending();
    if (_ownsClient) _baseClient.close();
  }

  void _checkAlive() {
    if (_disposed) {
      throw const OidcFailure('disposed', 'OIDC client has been disposed.');
    }
  }
}

Future<http.Response> _request(
  Future<http.Response> request,
  Future<void> cancelled,
) async {
  try {
    // Client.get/post completes only after its response body has been collected.
    return await Future.any<http.Response>([
      request,
      cancelled.then<http.Response>(
        (_) => throw const OidcFailure(
          'cancelled',
          'Authorization was cancelled.',
        ),
      ),
    ]).timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw const OidcFailure(
      'network_timeout',
      'OIDC endpoint request timed out.',
    );
  } on http.ClientException {
    throw const OidcFailure(
      'network_failed',
      'Unable to reach the OIDC endpoint.',
    );
  }
}

bool _safeAlgorithm(String value) => const [
  'RS256',
  'RS384',
  'RS512',
  'ES256',
  'ES384',
  'ES512',
  'PS256',
  'PS384',
  'PS512',
].contains(value);
bool _https(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;
bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;
bool _sameCallback(Uri a, Uri b) =>
    _sameOrigin(a, b) && a.path == b.path && a.userInfo.isEmpty;
String _random() {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

Map<String, dynamic> _json(http.Response response) {
  if (response.statusCode != 200) {
    throw const OidcFailure('http_failed', 'OIDC endpoint request failed.');
  }
  final value = jsonDecode(utf8.decode(response.bodyBytes));
  if (value is! Map<String, dynamic>) {
    throw const OidcFailure(
      'invalid_response',
      'OIDC endpoint returned invalid metadata.',
    );
  }
  return value;
}

final class _RestrictedClient extends http.BaseClient {
  final http.Client delegate;
  final Uri origin;
  _RestrictedClient(this.delegate, this.origin);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!_https(request.url) || !_sameOrigin(request.url, origin)) {
      throw const OidcFailure(
        'untrusted_endpoint',
        'OIDC endpoint origin is not trusted.',
      );
    }
    request.followRedirects = false;
    return delegate.send(request);
  }
}
