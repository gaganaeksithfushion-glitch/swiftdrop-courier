import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _callCenterController = TextEditingController();

  // සාමාන්‍යයෙන් තියෙන පණිවිඩය (Default)
  final String _defaultMsg = "ආයුබෝවන් {name}, ඔබගේ පාර්සලය (COD: Rs.{cod}) අද දිනයේ බෙදා හැරීමට නියමිතයි. කරුණාකර ඔබගේ Location එක එවන්න.";

  @override
  void initState() {
    super.initState();
    _loadMessage();
    _loadCallCenterNumber();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _callCenterController.dispose();
    super.dispose();
  }

  // සේව් කරලා තියෙන පණිවිඩය ලබා ගැනීම
  Future<void> _loadMessage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _msgController.text = prefs.getString('whatsapp_template') ?? _defaultMsg;
    });
  }

  // අලුත් පණිවිඩය සේව් කිරීම
  Future<void> _saveMessage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_template', _msgController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp පණිවිඩය සාර්ථකව සේව් විය!'), backgroundColor: Colors.green),
      );
    }
  }

  // Call Center WhatsApp Number එක Load කිරීම
  Future<void> _loadCallCenterNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _callCenterController.text = prefs.getString('call_center_whatsapp') ?? '';
    });
  }

  // Call Center WhatsApp Number එක Save කිරීම
  Future<void> _saveCallCenterNumber() async {
    final number = _callCenterController.text.trim();
    final phoneRegExp = RegExp(r'^(?:0|94|\+94)?(7[01245678][0-9]{7})$');
    if (number.isNotEmpty && !phoneRegExp.hasMatch(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර නිවැරදි WhatsApp අංකයක් ඇතුළත් කරන්න (උදා: 0712345678)'), backgroundColor: Colors.red),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('call_center_whatsapp', number);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call Center WhatsApp අංකය සාර්ථකව සේව් විය!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WhatsApp Message Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'පාරිභෝගිකයාගේ නම දැමීමට {name} ලෙසත්, COD මුදල දැමීමට {cod} ලෙසත් පණිවිඩය ඇතුලේ ටයිප් කරන්න. App එක මගින් එය ඉබේම පුරවනු ඇත.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _msgController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ඔබේ පණිවිඩය ටයිප් කරන්න',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Message'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveMessage,
            ),
            const Divider(height: 48),
            // 📞 Call Center WhatsApp Number - "No Answer" වුනු Parcel ගැන Call Center එකට Report කරන්න
            const Text('Call Center WhatsApp Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Route එකේදී Customer ට Call/WhatsApp කරලා උත්තර නැති වුනොත්, "No Answer" Button එකෙන් Details ටික Auto ලෙස මේ අංකයට WhatsApp කරන්න පුළුවන්.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _callCenterController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Call Center WhatsApp අංකය',
                hintText: '07X XXX XXXX',
                prefixIcon: Icon(Icons.support_agent),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Call Center Number'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveCallCenterNumber,
            ),
            const Divider(height: 48),
            // අනාගතයේදී තවත් Settings මෙතනට දාන්න පුළුවන් (උදා: Profile Name, Dark Mode)
            const Text('App Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('Version'),
              trailing: Text('1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}
