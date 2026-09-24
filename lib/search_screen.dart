import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'smart_scanner_screen.dart';

// ඕනෑම AppBar එකක actions ඇතුළට දාන්න: actions: [const SearchAction()]
class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Search',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final r = await DatabaseHelper.instance.searchDeliveries(q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searched = true;
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered':
        return Colors.green;
      case 'returned':
        return Colors.red;
      case 'confirmed':
        return Colors.blue;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _search,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'නම / Bill No / Phone / Address',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              _search('');
            },
          ),
        ],
      ),
      body: _results.isEmpty
          ? Center(child: Text(_searched ? 'කිසිවක් හමු නොවීය' : 'සොයන්න ටයිප් කරන්න', style: const TextStyle(color: Colors.grey)))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = _results[i];
                final status = (d['status'] ?? '').toString();
                return ListTile(
                  leading: CircleAvatar(backgroundColor: _statusColor(status), radius: 8),
                  title: Text((d['customerName'] ?? '').toString()),
                  subtitle: Text(
                    'Bill: ${d['billNumber'] ?? '-'}  •  ${d['phone'] ?? ''}\n${d['address'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 12)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SmartScannerScreen(deliveryToEdit: d)),
                    );
                    if (mounted) _search(_controller.text);
                  },
                );
              },
            ),
    );
  }
}
