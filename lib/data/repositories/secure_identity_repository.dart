import 'dart:convert';

import '../../core/utils/app_logger.dart';
import '../../core/identity.dart';
import '../../domain/entities/face_vector.dart';
import '../../domain/repositories/identity_repository.dart';
import '../datasources/secure_key_value_store.dart';

class SecureIdentityRepository implements IdentityRepository {
  SecureIdentityRepository(this._secureStore);

  final SecureKeyValueStore _secureStore;

  static const _privateKeyKey = 'identity.private_key.base64';
  static const _nameKey = 'identity.name';
  static const _ownerVectorKey = 'identity.owner.vector.json';
  static const _fallbackName = 'local-user';

  @override
  Future<void> saveIdentity(Ed25519Identity identity) async {
    AppLogger.log(
      'IDENTITY',
      'Saving identity "${identity.name}" to secure storage',
    );
    final privateKeyBytes = await identity.exportPrivateKeyBytes();
    await _secureStore.write(
      key: _privateKeyKey,
      value: base64Encode(privateKeyBytes),
    );
    await _secureStore.write(
      key: _nameKey,
      value: identity.name,
    );
    AppLogger.log(
      'IDENTITY',
      'Identity saved (publicKey=${identity.publicKeyHex.substring(0, 16)}...)',
    );
  }

  @override
  Future<Ed25519Identity?> getIdentity() async {
    AppLogger.log('IDENTITY', 'Loading identity from secure storage');
    final privateKeyBase64 = await _secureStore.read(key: _privateKeyKey);
    if (privateKeyBase64 == null || privateKeyBase64.isEmpty) {
      AppLogger.log('IDENTITY', 'No identity found in secure storage');
      return null;
    }

    final name = await _secureStore.read(key: _nameKey) ?? _fallbackName;

    try {
      final privateKeyBytes = base64Decode(privateKeyBase64);
      final identity = await Identity.fromPrivateKeyBytes(
        name: name,
        privateKeyBytes: privateKeyBytes,
      );
      AppLogger.log(
        'IDENTITY',
        'Identity loaded (publicKey=${identity.publicKeyHex.substring(0, 16)}...)',
      );
      return identity;
    } on FormatException {
      AppLogger.error('IDENTITY', 'Failed to decode stored private key');
      return null;
    } on ArgumentError {
      AppLogger.error('IDENTITY', 'Stored private key bytes are invalid');
      return null;
    } on StateError {
      AppLogger.error('IDENTITY', 'Failed to rehydrate identity from storage');
      return null;
    }
  }

  @override
  Future<void> saveOwnerFaceVector(FaceVector vector) async {
    AppLogger.log(
      'IDENTITY',
      'Saving owner face vector (${vector.values.length} dims)',
    );
    await _secureStore.write(
      key: _ownerVectorKey,
      value: jsonEncode(vector.values),
    );
  }

  @override
  Future<FaceVector?> getOwnerFaceVector() async {
    AppLogger.log('IDENTITY', 'Loading owner face vector');
    final encoded = await _secureStore.read(key: _ownerVectorKey);
    if (encoded == null || encoded.isEmpty) {
      AppLogger.log('IDENTITY', 'No owner face vector found');
      return null;
    }

    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final values = decoded.map((value) => (value as num).toDouble()).toList();
      if (values.isEmpty) {
        AppLogger.error('IDENTITY', 'Stored owner vector is empty');
        return null;
      }
      return FaceVector(values);
    } on FormatException {
      AppLogger.error('IDENTITY', 'Failed to decode owner vector JSON');
      return null;
    } on TypeError {
      AppLogger.error('IDENTITY', 'Owner vector JSON has invalid format');
      return null;
    } on ArgumentError {
      AppLogger.error('IDENTITY', 'Owner vector data is invalid');
      return null;
    }
  }
}
