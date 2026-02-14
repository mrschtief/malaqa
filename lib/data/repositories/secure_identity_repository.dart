import 'dart:convert';

import '../../core/identity.dart';
import '../../domain/repositories/identity_repository.dart';
import '../datasources/secure_key_value_store.dart';

class SecureIdentityRepository implements IdentityRepository {
  SecureIdentityRepository(this._secureStore);

  final SecureKeyValueStore _secureStore;

  static const _privateKeyKey = 'identity.private_key.base64';
  static const _nameKey = 'identity.name';
  static const _fallbackName = 'local-user';

  @override
  Future<void> saveIdentity(Ed25519Identity identity) async {
    final privateKeyBytes = await identity.exportPrivateKeyBytes();
    await _secureStore.write(
      key: _privateKeyKey,
      value: base64Encode(privateKeyBytes),
    );
    await _secureStore.write(
      key: _nameKey,
      value: identity.name,
    );
  }

  @override
  Future<Ed25519Identity?> getIdentity() async {
    final privateKeyBase64 = await _secureStore.read(key: _privateKeyKey);
    if (privateKeyBase64 == null || privateKeyBase64.isEmpty) {
      return null;
    }

    final name = await _secureStore.read(key: _nameKey) ?? _fallbackName;

    try {
      final privateKeyBytes = base64Decode(privateKeyBase64);
      return Identity.fromPrivateKeyBytes(
        name: name,
        privateKeyBytes: privateKeyBytes,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }
}
