import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart'; // අපි නිර්මාණය කළ තීම් ෆයිල් එක
import 'login_screen.dart';
import 'smart_scanner_screen.dart';
import 'pending_calls_screen.dart';
import 'route_list_screen.dart';
import 'end_of_day_report_screen.dart';
import 'settings_screen.dart';

void main() {
  runApp(const ShiftDropApp());
}

class ShiftDropApp extends StatelessWidget {
  const ShiftDropApp({super.key});

  Future<String?> _getSavedWhatsappNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('whatsapp_number');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiftDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<String?>(
        future: _getSavedWhatsappNumber(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final savedNumber = snapshot.data;
          if (savedNumber != null && savedNumber.isNotEmpty) {
            // දැනටමත් login වෙලා තියෙනවා නම් කෙළින්ම Dashboard එකට
            return MainNavigationShell(whatsappNumber: savedNumber);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final String whatsappNumber;
  const MainNavigationShell({super.key, required this.whatsappNumber});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // යටින් ඇති Navigation Bar එක සඳහා ප්‍රධාන තිර 4
  List<Widget> get _screens => [
        DashboardScreen(whatsappNumber: widget.whatsappNumber),
        const RouteListScreen(),      // My Route
        const SettingsScreen(),       // Messages / Settings
        const EndOfDayReportScreen(), // Reports / Profile
      ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('whatsapp_number');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShiftDrop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_rounded),
            label: 'My Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

// ප්‍රධාන Dashboard තිරය
class DashboardScreen extends StatelessWidget {
  final String whatsappNumber;
  const DashboardScreen({super.key, required this.whatsappNumber});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Active WhatsApp: $whatsappNumber',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'Smart Scanner & Entry',
          subtitle: 'Scan packages & add manifest entries.',
          icon: Icons.qr_code_scanner_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartScannerScreen()));
          },
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'Pending & Morning Calls',
          subtitle: 'Review pending stops & make notifications.',
          icon: Icons.contact_phone_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingCallsScreen()));
          },
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'Route Map & Status',
          subtitle: 'View assigned route & update delivery status.',
          icon: Icons.map_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RouteListScreen()));
          },
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'End-of-Day Reports',
          subtitle: 'Submit daily logs & complete reporting.',
          icon: Icons.bar_chart_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EndOfDayReportScreen()));
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D3748)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
