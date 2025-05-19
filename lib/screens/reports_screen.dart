import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_plaza/screens/filtered_items_screen.dart';

class ReportsScreen extends StatelessWidget {
  final Function(String, Map<String, dynamic>)? onItemSelect;

  ReportsScreen({this.onItemSelect});

  Future<Map<String, dynamic>> _fetchStats() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final formatter = DateFormat('yyyy-MM-dd');

    final snapshot = await FirebaseFirestore.instance.collection('inventory').get();
    final allDocs = snapshot.docs;

    int availableCount = 0;
    int soldCount = 0;
    double availableValue = 0;
    int soldThisMonth = 0;

    for (var doc in allDocs) {
      final data = doc.data();

      if ((data['isSold'] ?? false) == true) {
        soldCount++;

        // Check if sold this month
        final soldDate = data['sellDate'];
        if (soldDate != null) {
          try {
            final parsedDate = formatter.parse(soldDate);
            if (parsedDate.isAfter(startOfMonth.subtract(const Duration(days: 1)))) {
              soldThisMonth++;
            }
          } catch (_) {}
        }
      } else {
        availableCount++;
        availableValue += (data['purchasePrice'] ?? 0).toDouble();
      }
    }

    return {
      'availableCount': availableCount,
      'soldCount': soldCount,
      'availableValue': availableValue,
      'soldThisMonth': soldThisMonth,
    };
  }

  void _navigateToItemsList(BuildContext context, bool soldStatus) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilteredItemsScreen(isSold: soldStatus),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final stats = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatCard(
                      title: "Available Items",
                      value: stats['availableCount'].toString(),
                      icon: Icons.inventory_2_outlined,
                      color: Colors.green,
                      onTap: () => _navigateToItemsList(context, false),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      title: "Sold Items",
                      value: stats['soldCount'].toString(),
                      icon: Icons.sell,
                      color: Colors.orange,
                      onTap: () => _navigateToItemsList(context, true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard(
                      title: "Available Value",
                      value: "₹${stats['availableValue'].toStringAsFixed(2)}",
                      icon: Icons.account_balance_wallet,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      title: "Sold This Month",
                      value: stats['soldThisMonth'].toString(),
                      icon: Icons.calendar_today,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
