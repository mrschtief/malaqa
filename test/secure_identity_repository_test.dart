import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/data/datasources/secure_key_value_store.dart';
import 'package:malaqa/data/repositories/secure_identity_repository.dart';
import 'package:malaqa/domain/entities/face_vector.dart';

class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}

void main() {
  test('SecureIdentityRepository returns null when no identity is stored',
      () async {
    final repository = SecureIdentityRepository(InMemorySecureStore());

    final loaded = await repository.getIdentity();
    expect(loaded, isNull);
  });

  test('SecureIdentityRepository saves and restores identity', () async {
    final repository = SecureIdentityRepository(InMemorySecureStore());
    final original = await Identity.create(name: 'alice-local');

    await repository.saveIdentity(original);
    final loaded = await repository.getIdentity();

    expect(loaded, isNotNull);
    expect(loaded!.name, equals('alice-local'));
    expect(loaded.publicKeyHex, equals(original.publicKeyHex));
  });

  test('SecureIdentityRepository saves and restores owner face vector',
      () async {
    final repository = SecureIdentityRepository(InMemorySecureStore());
    final original = FaceVector(List<double>.filled(512, 0.1234));

    await repository.saveOwnerFaceVector(original);
    final loaded = await repository.getOwnerFaceVector();

    expect(loaded, isNotNull);
    expect(loaded!.values, hasLength(512));
    expect(loaded.values.first, closeTo(0.1234, 0.0000001));
    expect(loaded.values.last, closeTo(0.1234, 0.0000001));
  });
}
