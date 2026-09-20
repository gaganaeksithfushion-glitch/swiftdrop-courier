import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'main.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  final String registeredPhone;
  const LoginScreen({super.key, required this.registeredPhone});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර Password එක ඇතුළත් කරන්න.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('registered_password_hash');
    final enteredHash = _hashPassword(_passwordController.text);

    if (storedHash != enteredHash) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password එක වැරදියි!'), backgroundColor: Colors.red),
      );
      return;
    }

    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainNavigationShell(whatsappNumber: widget.registeredPhone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('ShiftDrop Courier', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  widget.registeredPhone,
                  style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    // Different number එකකින් register වෙන්න ඕන නම් (device එක වෙනස් උනොත් වගේ)
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('registered_phone');
                    await prefs.remove('registered_password_hash');
                    await prefs.remove('is_logged_in');
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    );
                  },
                  child: const Text('වෙන Phone Number එකකින් Register වෙන්න'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
