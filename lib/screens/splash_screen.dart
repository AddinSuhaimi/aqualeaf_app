import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:aqualeaf_app/config.dart';
import 'api_settings_screen.dart';

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
    await AppConfig.init();  // ONLY FOR DEV, REMOVE IN PRODUCTION
    await Future.delayed(const Duration(seconds: 1)); // small splash delay
    final token = await TokenStorage.getToken();

    if (token == null) {
      _goTo(const LoginScreen());
      return;
    }

    // Optional: verify token validity with backend
    final response = await ApiService.fetchFarmDetails();
    if (response != null && response['__unauthorized'] != true) {
      _goTo(const HomeScreen());
    } else {
      await TokenStorage.clearToken();
      _goTo(const LoginScreen());
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

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.settings),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ApiSettingsScreen()),
          );
        },
      ),

    );
  }
}
