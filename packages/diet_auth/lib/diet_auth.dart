library;

export 'package:diet_oidc/diet_oidc.dart' show OidcSession;

export 'src/client.dart';
export 'src/types.dart';

export 'src/auxiliary_stub.dart'
    if (dart.library.io) 'src/auxiliary_native.dart';
