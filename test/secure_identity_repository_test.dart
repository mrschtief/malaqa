import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/identity.dart';
import 'package:malaqa/data/datasources/secure_key_value_store.dart';
import 'package:malaqa/data/repositories/secure_identity_repository.dart';

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
}
