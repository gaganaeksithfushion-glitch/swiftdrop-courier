import 'package:flutter/material.dart';
// අපි නිර්මාණය කළ අලුත් තිරයන් 3 මෙතැනින් සම්බන්ධ වේ
import 'smart_scanner_screen.dart'; 
import 'pending_calls_screen.dart';
import 'route_list_screen.dart';

void main() {
  runApp(const ShiftDropApp());
}

class ShiftDropApp extends StatelessWidget {
  const ShiftDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiftDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A148C), // ඔබේ බ්‍රෑන්ඩ් වර්ණය (Deep Purple)
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // පහළ Navigation Bar එක සඳහා තිරයන් 4
  final List<Widget> _screens = [
    const DashboardScreen(),
    const Center(child: Text('My Route (Map Integration Goes Here)')),
    const Center(child: Text('Messages (WhatsApp Logs Go Here)')),
    const Center(child: Text('Profile (Settings Go Here)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ShiftDrop',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                ),
              ],
            ),
          )
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
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.route), label: 'My Route'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ප්‍රධාන Dashboard තිරය
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildDashboardCard(
          context,
          title: 'Smart Scanner & Entry',
          subtitle: 'Scan printed lists or waybills to add parcels.',
          icon: Icons.qr_code_scanner,
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'Pending & Morning Calls',
          subtitle: 'Review pending stops & make confirmation calls.',
          icon: Icons.contact_phone_outlined,
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          context,
          title: 'Route Map & Status',
          subtitle: 'View confirmed parcels and mark as delivered.',
          icon: Icons.map_outlined,
        ),
      ],
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required String subtitle, required IconData icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(subtitle),
        ),
        onTap: () {
          // අදාළ බොත්තම එබූ විට නියමිත තිරය වෙත ගමන් කිරීමේ කේතය
          if (title == 'Smart Scanner & Entry') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartScannerScreen()));
          } else if (title == 'Pending & Morning Calls') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingCallsScreen()));
          } else if (title == 'Route Map & Status') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RouteListScreen()));
          }
        },
      ),
    );
  }
}
