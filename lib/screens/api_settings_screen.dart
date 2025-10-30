import 'package:flutter/material.dart';
import '../config.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the current URL
    _controller = TextEditingController(text: AppConfig.apiBaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter API Base URL',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://192.168.x.x:3000/api',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await AppConfig.setApiBaseUrl(_controller.text.trim());
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API URL saved!')),
                );
                Navigator.pop(context); // return to previous screen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
