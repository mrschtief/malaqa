import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._({
    required SharedPreferences prefs,
  }) : _prefs = prefs {
    _isFirstRun = !(_prefs.getBool(_onboardingCompletedKey) ?? false);
    _nearbyVisibility = _prefs.getBool(_nearbyVisibilityKey) ?? true;
  }

  final SharedPreferences _prefs;

  static const _onboardingCompletedKey = 'app.onboarding.completed';
  static const _nearbyVisibilityKey = 'settings.nearby_visibility';

  late bool _isFirstRun;
  late bool _nearbyVisibility;

  bool get isFirstRun => _isFirstRun;
  bool get nearbyVisibility => _nearbyVisibility;

  static Future<AppSettingsService> load({
    SharedPreferences? sharedPreferences,
  }) async {
    if (sharedPreferences != null) {
      return AppSettingsService._(prefs: sharedPreferences);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettingsService._(prefs: prefs);
    } on MissingPluginException {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      return AppSettingsService._(prefs: prefs);
    }
  }

  Future<void> completeOnboarding() async {
    _isFirstRun = false;
    await _prefs.setBool(_onboardingCompletedKey, true);
    AppLogger.log('ONBOARDING', 'Onboarding marked as completed');
    notifyListeners();
  }

  Future<void> setNearbyVisibility(bool enabled) async {
    if (_nearbyVisibility == enabled) {
      return;
    }
    _nearbyVisibility = enabled;
    await _prefs.setBool(_nearbyVisibilityKey, enabled);
    AppLogger.log(
      'SETTINGS',
      'Nearby visibility updated (enabled=$enabled)',
    );
    notifyListeners();
  }

  Future<void> resetToFirstRun() async {
    _isFirstRun = true;
    _nearbyVisibility = true;
    await _prefs.remove(_onboardingCompletedKey);
    await _prefs.remove(_nearbyVisibilityKey);
    AppLogger.log('SETTINGS', 'App settings reset to first-run defaults');
    notifyListeners();
  }
}
