import 'package:flutter/widgets.dart';

import 'core/di/service_locator.dart';
import 'domain/use_cases/ensure_local_identity_use_case.dart';
import 'presentation/app/malaqa_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await getIt<EnsureLocalIdentityUseCase>().execute();
  runApp(const MalaqaApp());
}
