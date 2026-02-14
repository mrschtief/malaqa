import 'package:flutter/widgets.dart';

import 'core/di/service_locator.dart';
import 'presentation/app/malaqa_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MalaqaApp());
}
