import 'package:flutter/material.dart';

class MalaqaApp extends StatelessWidget {
  const MalaqaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('malaqa core initialized'),
        ),
      ),
    );
  }
}
