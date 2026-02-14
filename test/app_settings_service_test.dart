import 'package:flutter_test/flutter_test.dart';
import 'package:malaqa/core/services/app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to first-run true and nearby visibility enabled', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final settings = await AppSettingsService.load();

    expect(settings.isFirstRun, isTrue);
    expect(settings.nearbyVisibility, isTrue);
  });

  test('completeOnboarding persists completion flag', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final settingsA = await AppSettingsService.load();
    await settingsA.completeOnboarding();

    final settingsB = await AppSettingsService.load();
    expect(settingsB.isFirstRun, isFalse);
  });

  test('setNearbyVisibility persists toggle state', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final settingsA = await AppSettingsService.load();
    await settingsA.setNearbyVisibility(false);

    final settingsB = await AppSettingsService.load();
    expect(settingsB.nearbyVisibility, isFalse);
  });

  test('resetToFirstRun restores defaults', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final settings = await AppSettingsService.load();
    await settings.completeOnboarding();
    await settings.setNearbyVisibility(false);

    await settings.resetToFirstRun();

    expect(settings.isFirstRun, isTrue);
    expect(settings.nearbyVisibility, isTrue);
  });
}
