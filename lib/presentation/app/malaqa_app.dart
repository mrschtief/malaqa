import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/app_settings_service.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/meeting/meeting_cubit.dart';
import '../blocs/proximity/proximity_cubit.dart';
import '../pages/auth_page.dart';
import '../pages/onboarding_page.dart';

class MalaqaApp extends StatelessWidget {
  const MalaqaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => getIt<AuthCubit>(),
        ),
        BlocProvider<MeetingCubit>(
          create: (_) => getIt<MeetingCubit>(),
        ),
        BlocProvider<ProximityCubit>(
          create: (_) => getIt<ProximityCubit>(),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final settings = getIt<AppSettingsService>();
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        if (settings.isFirstRun) {
          return OnboardingPage(
            onCompleted: () async {
              // No-op; state transition is driven by AppSettingsService.
            },
          );
        }
        return const AuthPage();
      },
    );
  }
}
