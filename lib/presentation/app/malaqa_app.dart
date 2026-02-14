import 'package:flutter/material.dart';

import '../pages/mirror_page.dart';

class MalaqaApp extends StatelessWidget {
  const MalaqaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MirrorPage(),
    );
  }
}
