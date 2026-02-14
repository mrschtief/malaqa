import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/utils/app_logger.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onCompleted,
  });

  final Future<void> Function()? onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  var _pageIndex = 0;
  var _isBootstrapping = false;

  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.face_retouching_natural,
      title: 'Dein Gesicht ist dein Schlüssel',
      description: 'Keine Passwörter. Keine zentrale Datenbank.',
    ),
    _OnboardingSlide(
      icon: Icons.link_rounded,
      title: 'Echte Begegnungen. Verifizierte Ketten.',
      description: 'Jeder neue Knoten baut auf realen Treffen auf.',
    ),
    _OnboardingSlide(
      icon: Icons.shield_outlined,
      title: 'Kamera + Standort + Nearby',
      description: 'Diese Rechte sind nötig, damit Malaqa korrekt arbeitet.',
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_isBootstrapping) {
      return;
    }
    setState(() => _isBootstrapping = true);

    try {
      await _requestAllRequiredPermissions();
      final settings = getIt<AppSettingsService>();
      await settings.completeOnboarding();

      if (widget.onCompleted != null) {
        await widget.onCompleted!();
      }

      AppLogger.log('ONBOARDING', 'User completed onboarding flow');
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  Future<void> _requestAllRequiredPermissions() async {
    final permissions = <Permission>[
      Permission.camera,
      Permission.locationWhenInUse,
      ..._nearbyPermissionsForPlatform(),
    ];

    for (final permission in permissions) {
      final status = await _requestPermission(permission);
      AppLogger.log(
        'ONBOARDING',
        'Permission ${permission.toString()} -> $status',
      );
    }
  }

  List<Permission> _nearbyPermissionsForPlatform() {
    if (kIsWeb) {
      return const <Permission>[];
    }
    if (Platform.isAndroid) {
      return const <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ];
    }
    if (Platform.isIOS) {
      return const <Permission>[Permission.bluetooth];
    }
    return const <Permission>[];
  }

  Future<PermissionStatus> _requestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) {
      return status;
    }
    return permission.request();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0A1A2D),
                            Color(0xFF051320),
                          ],
                        ),
                        border: Border.all(
                          color:
                              const Color(0xFF00D1FF).withValues(alpha: 0.32),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D1FF)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  slide.icon,
                                  size: 28,
                                  color: const Color(0xFF00D1FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              slide.title,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.description,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Slide ${index + 1}/${_slides.length}',
                              style: TextStyle(
                                color: const Color(0xFF00D1FF)
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _pageIndex == index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _pageIndex == index
                        ? const Color(0xFF00D1FF)
                        : Colors.white24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBootstrapping ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: const Color(0xFF031321),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  child: Text(
                    _isBootstrapping
                        ? 'Permissions werden gesetzt...'
                        : 'Initiiere Protokoll',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
