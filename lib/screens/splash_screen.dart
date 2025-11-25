import 'package:flutter/material.dart';
import '../services/secure_storage.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:aqualeaf_app/config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await AppConfig.init();  // Only for development
    await Future.delayed(const Duration(seconds: 1)); // small splash delay

    final result = await ApiService.checkLoginStatus();

    if (!mounted) return;

    switch (result["status"]) {
      case "no_token":
        _goTo(const LoginScreen());
        break;

      case "online_valid":
        _goTo(const HomeScreen());
        break;

      case "offline_allowed":
        _goTo(const HomeScreen());
        break;

      case "online_invalid":
      // Token expired -> user must log in again
        await SecureStorage.clearAll();
        _goTo(const LoginScreen());
        break;

      case "server_error":
      // Cannot reach server but token exists -> allow offline mode
        _goTo(const HomeScreen());
        break;

      default:
      // Fallback: allow offline mode
        _goTo(const HomeScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Checking login status..."),
          ],
        ),
      ),
    );
  }
}
