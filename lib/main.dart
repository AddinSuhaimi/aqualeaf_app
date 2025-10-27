import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AquaLeafApp());
}

class AquaLeafApp extends StatelessWidget {
  const AquaLeafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AquaLeaf',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const SplashScreen(), // ✅ start here
    );
  }
}

