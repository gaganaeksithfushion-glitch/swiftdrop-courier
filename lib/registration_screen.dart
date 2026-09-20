import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'main.dart';

// ==========================================================================
// ⚠️ notify.lk එකේ account එකෙන් ලබාගත් values මෙතනට දාන්න
// ==========================================================================
const String _notifyUserId = '33042';
const String _notifyApiKey = 'aLKp2539XduyPECtYJio';
const String _notifySenderId = 'NotifyDEMO'; // Production සඳහා approved sender ID එකක් පාවිච්චි කරන්න

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _generatedOtp;
  String _normalizedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // Sri Lankan format 07XXXXXXXX → notify.lk ට ඕන 94XXXXXXXXX format එකට
  String _toInternationalFormat(String phone) {
    if (phone.startsWith('0')) return '94${phone.substring(1)}';
    if (phone.startsWith('+94')) return phone.substring(1);
    if (phone.startsWith('94')) return phone;
    return phone;
  }

  Future<void> _sendOtp() async {
    String phone = _phoneController.text.trim();
    final phoneRegExp = RegExp(r'^(?:0|94|\+94)?(7[01245678][0-9]{7})$');

    if (!phoneRegExp.hasMatch(phone)) {
      _showSnack('කරුණාකර නිවැරදි දුරකථන අංකයක් ඇතුළත් කරන්න (උදා: 0712345678)', Colors.red);
      return;
    }
    if (_passwordController.text.length < 4) {
      _showSnack('Password අකුරු 4කට වඩා දිග විය යුතුයි', Colors.red);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack('Password දෙකම එකිනෙකට සමාන විය යුතුයි', Colors.red);
      return;
    }

    // 0XXXXXXXXX format එකට normalize කිරීම
    if (phone.startsWith('+94')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('94') && phone.length == 11) {
      phone = '0${phone.substring(2)}';
    }
    _normalizedPhone = phone;

    setState(() => _isLoading = true);

    // 6-digit OTP එකක් generate කිරීම
    _generatedOtp = (100000 + Random().nextInt(900000)).toString();

    try {
      final url = Uri.parse('https://app.notify.lk/api/v1/send').replace(queryParameters: {
        'user_id': _notifyUserId,
        'api_key': _notifyApiKey,
        'sender_id': _notifySenderId,
        'to': _toInternationalFormat(_normalizedPhone),
        'message': 'ShiftDrop verification code: $_generatedOtp',
      });

      final response = await http.get(url);
      final decoded = jsonDecode(response.body);

      if (decoded['status'] == 'success') {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _showSnack('OTP එක SMS එකෙන් යවා ඇත!', Colors.green);
      } else {
        setState(() => _isLoading = false);
        _showSnack('OTP යැවීමේ දෝෂයක්: ${decoded['data'] ?? response.body}', Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('SMS API දෝෂයක්: $e', Colors.red);
    }
  }

  Future<void> _verifyOtpAndRegister() async {
    if (_otpController.text.trim() != _generatedOtp) {
      _showSnack('OTP එක වැරදියි! ආයෙත් check කරන්න.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('registered_phone', _normalizedPhone);
    await prefs.setString('registered_password_hash', _hashPassword(_passwordController.text));
    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainNavigationShell(whatsappNumber: _normalizedPhone)),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping, size: 70, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('ShiftDrop Courier', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'අලුත් ගිණුමක් හදාගන්න',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                if (!_otpSent) ...[
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '07X XXX XXXX',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    onPressed: _isLoading ? null : _sendOtp,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  Text('$_normalizedPhone ට යවපු OTP එක ඇතුළත් කරන්න:', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    maxLength: 6,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    onPressed: _isLoading ? null : _verifyOtpAndRegister,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify & Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    child: const Text('Phone number එක වැරදියි ද? ආපහු යන්න'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
