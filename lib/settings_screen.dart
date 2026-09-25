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
  final TextEditingController _noAnswerMsgController = TextEditingController();
  final TextEditingController _routeNoAnswerMsgController = TextEditingController();

  // සාමාන්‍යයෙන් තියෙන පණිවිඩය (Default)
  final String _defaultMsg = "ආයුබෝවන් {name}, ඔබගේ පාර්සලය (COD: Rs.{cod}) අද දිනයේ බෙදා හැරීමට නියමිතයි. කරුණාකර ඔබගේ Location එක එවන්න.";

  // Call Center එකට යවන "No Answer" පණිවිඩයේ Default Template - Pending Calls Screen එකට
  final String _defaultNoAnswerMsg =
      "Bill No: {bill}\nName: {name}\nItem: {item}\nPhone: {phone}\nis not responding.";

  // Call Center එකට යවන "No Answer" පණිවිඩයේ Default Template - My Route Screen එකට
  final String _defaultRouteNoAnswerMsg =
      "Bill No: {bill}\nName: {name}\nItem: {item}\nPhone: {phone}\nnot responding at location.";

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _callCenterController.dispose();
    _noAnswerMsgController.dispose();
    _routeNoAnswerMsgController.dispose();
    super.dispose();
  }

  // සේව් කරලා තියෙන පණිවිඩය ලබා ගැනීම
  Future<void> _loadMessage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _msgController.text = prefs.getString('whatsapp_template') ?? _defaultMsg;
      _callCenterController.text = prefs.getString('call_center_whatsapp') ?? '';
      _noAnswerMsgController.text = prefs.getString('no_answer_template') ?? _defaultNoAnswerMsg;
      _routeNoAnswerMsgController.text = prefs.getString('route_no_answer_template') ?? _defaultRouteNoAnswerMsg;
    });
  }

  // අලුත් පණිවිඩය සේව් කිරීම
  Future<void> _saveMessage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_template', _msgController.text);
    await prefs.setString('call_center_whatsapp', _callCenterController.text.trim());
    await prefs.setString(
      'no_answer_template',
      _noAnswerMsgController.text.trim().isEmpty ? _defaultNoAnswerMsg : _noAnswerMsgController.text,
    );
    await prefs.setString(
      'route_no_answer_template',
      _routeNoAnswerMsgController.text.trim().isEmpty ? _defaultRouteNoAnswerMsg : _routeNoAnswerMsgController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings සාර්ථකව සේව් විය!'), backgroundColor: Colors.green),
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
            const Divider(height: 48),

            // 📞 Call Center WhatsApp Number
            const Text('Call Center WhatsApp Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Pending Calls / My Route තිරවල "No Answer" click කරාම, පාර්සල් විස්තර WhatsApp හරහා යවන්නේ මේ Number එකටයි. (උදා: 0771234567)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _callCenterController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Call Center Number එක ඇතුළත් කරන්න',
                prefixIcon: Icon(Icons.support_agent),
              ),
            ),
            const SizedBox(height: 24),

            // 📝 No Answer Message Template - Pending Calls Screen
            const Text('"No Answer" Message - Pending Calls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Pending Calls තිරයේ "No Answer" click කරාම Call Center එකට යවන පණිවිඩය. {bill}, {name}, {item}, {phone} ස්වයංක්‍රීයව පුරවනු ඇත.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noAnswerMsgController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'No Answer පණිවිඩය (Pending Calls)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // 📝 No Answer Message Template - My Route Screen
            const Text('"No Answer" Message - My Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'My Route තිරයේ "No Answer" click කරාම Call Center එකට යවන පණිවිඩය. {bill}, {name}, {item}, {phone} ස්වයංක්‍රීයව පුරවනු ඇත.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _routeNoAnswerMsgController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'No Answer පණිවිඩය (My Route)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveMessage,
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
