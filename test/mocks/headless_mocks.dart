import 'package:malaqa/core/utils/app_logger.dart';
import 'package:malaqa/malaqa.dart';

class MockBiometricScanner implements BiometricScanner<String> {
  static const int _vectorLength = 512;

  @override
  Future<FaceVector?> captureFace(String input) async {
    AppLogger.log('MOCK', 'Scanning fake image "$input"...');
    switch (input) {
      case 'A':
        return FaceVector(List<double>.filled(_vectorLength, 0.1));
      case 'B':
        return FaceVector(List<double>.filled(_vectorLength, 0.9));
      default:
        AppLogger.error('MOCK', 'Unknown fake image key: $input');
        return null;
    }
  }

  @override
  Future<List<FaceVector>> scanFaces(
    String input,
    List<FaceBounds> allFaces,
  ) async {
    AppLogger.log(
      'MOCK',
      'Scanning fake multi-face image "$input" (${allFaces.length} faces)',
    );
    if (input != 'MEETING' || allFaces.length < 2) {
      return const <FaceVector>[];
    }

    return <FaceVector>[
      FaceVector(List<double>.filled(_vectorLength, 0.1)),
      FaceVector(List<double>.filled(_vectorLength, 0.9)),
    ];
  }
}

class HeadlessSecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async {
    AppLogger.log('MOCK', 'Reading key "$key" from mock secure store');
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    AppLogger.log('MOCK', 'Writing key "$key" to mock secure store');
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    AppLogger.log('MOCK', 'Deleting key "$key" from mock secure store');
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    AppLogger.log('MOCK', 'Deleting all keys from mock secure store');
    _values.clear();
  }
}
