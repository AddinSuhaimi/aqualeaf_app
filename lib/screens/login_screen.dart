import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'species_selection_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _farmController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    final result = await ApiService.loginUser(
      _farmController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      final token = result['token'];
      await TokenStorage.saveToken(token); // save securely
      print("Stored Token: $token");

      final savedToken = await TokenStorage.getToken();
      print("Retrieved token: $savedToken");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Login successful")),
      );

      // Check if species already chosen
      final species = await TokenStorage.getSpecies();

      if (!mounted) return;

      if (species == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SpeciesSelectionScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Login failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006400), // Dark green background
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + App Name
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      "assets/aqualeaf-logo.png",
                      height: 100,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // White Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Email field
                    TextField(
                      controller: _farmController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _handleLogin,
                        child: const Text(
                          "Sign In",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
