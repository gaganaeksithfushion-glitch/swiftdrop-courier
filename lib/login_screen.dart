import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    String phone = _phoneController.text.trim();
    final phoneRegExp = RegExp(r'^(?:0|94|\+94)?(7[01245678][0-9]{7})$');

    if (!phoneRegExp.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('කරුණාකර නිවැරදි WhatsApp අංකයක් ඇතුළත් කරන්න (උදා: 0712345678)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 0XXXXXXXXX format එකට normalize කිරීම
    if (phone.startsWith('+94')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('94') && phone.length == 11) {
      phone = '0${phone.substring(2)}';
    }

    setState(() => _isLoading = true);

    // App එක close කරලා ආයෙත් open කළත් login state එක මතක තියාගැනීමට save කිරීම
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_number', phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainNavigationShell(whatsappNumber: phone)),
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
                const Text(
                  'ShiftDrop Courier',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ඔබේ WhatsApp අංකය ඇතුළත් කර ඇප් එකට පිවිසෙන්න.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '07X XXX XXXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
