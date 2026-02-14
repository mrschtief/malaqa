import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/meeting/meeting_cubit.dart';
import '../blocs/proximity/proximity_cubit.dart';
import '../pages/auth_page.dart';

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
        home: AuthPage(),
      ),
    );
  }
}
