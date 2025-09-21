import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const LoginScreen(),
    );
  }
}
