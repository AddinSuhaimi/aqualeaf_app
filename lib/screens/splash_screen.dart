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

    final status = result["status"];

    if (!mounted) return;

    switch (status) {

    // Never logged in OR refresh token expired
      case "no_token":
      case "invalid":
        await SecureStorage.clearAll(); // clear tokens, species, cached data if you want
        _goTo(const LoginScreen());
        break;

    // Access token is valid OR was successfully refreshed
      case "valid":
      case "refreshed": // if you choose to return this separately
        _goTo(const HomeScreen());
        break;

    // User has logged in before, but is currently offline
      case "offline_allowed":
        _goTo(const HomeScreen());
        break;

    // Fallback: be generous and treat as offline-allowed
      default:
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
