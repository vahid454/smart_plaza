import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_plaza/screens/filtered_items_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopkeeperSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Shopkeeper")),
      body: FutureBuilder<List<String>>(
        future: _fetchShopkeepers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final shopkeepers = snapshot.data!;
          if (shopkeepers.isEmpty) {
            return const Center(
              child: Text(
                "No shopkeepers found.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shopkeepers.length,
            itemBuilder: (context, index) {
              final name = shopkeepers[index];
              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportsScreen(shopkeeperName: name),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<String>> _fetchShopkeepers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    final shopkeepers = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final name = data['username'] ?? data['name'];
      if (name != null) {
        shopkeepers.add(name.toString());
      }
    }
    return shopkeepers.toList();
  }
}

class ReportsScreen extends StatefulWidget {
  final String shopkeeperName;

  ReportsScreen({required this.shopkeeperName});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {

  Future<Map<String, dynamic>> _fetchStats(String shopkeeper) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final formatter = DateFormat('yyyy-MM-dd');

    final snapshot = await FirebaseFirestore.instance
        .collection('inventory')
        .where('shopkeeper.name', isEqualTo: shopkeeper)
        .get();

    final allDocs = snapshot.docs;

    int availableCount = 0;
    int soldCount = 0;
    double availableValue = 0;
    int soldThisMonth = 0;

    double totalPurchaseCost = 0;
    double totalPaymentAmount = 0;
    double pendingPaymentsAmount = 0;

    for (var doc in allDocs) {
      final data = doc.data();

      if ((data['isSold'] ?? false) == true) {
        soldCount++;

        totalPurchaseCost += (data['purchasePrice'] ?? 0).toDouble();
        totalPaymentAmount += (data['paymentAmount'] ?? 0).toDouble();

        final soldDate = data['sellDate'];
        if (soldDate != null) {
          try {
            final parsedDate = formatter.parse(soldDate);
            if (parsedDate.isAfter(startOfMonth.subtract(const Duration(days: 1)))) {
              soldThisMonth++;
            }
          } catch (_) {}
        }

        final isSold = (data['isSold'] ?? false) == true;
        final payment = (data['paymentAmount'] is num) ? data['paymentAmount'].toDouble() : double.tryParse(data['paymentAmount'].toString()) ?? 0.0;

        if (isSold && payment == 0.0) {
          pendingPaymentsAmount += (data['purchasePrice'] ?? 0).toDouble();
        }
      } else {
        availableCount++;
        availableValue += (data['purchasePrice'] ?? 0).toDouble();
      }
    }

    double profit = 0;
    for (var doc in allDocs) {
      final data = doc.data();
      if ((data['isSold'] ?? false) == true && (data['paymentAmount'] ?? 0) > 0) {
        final payment = (data['paymentAmount'] ?? 0).toDouble();
        final purchase = (data['purchasePrice'] ?? 0).toDouble();
        profit += payment - purchase;
      }
    }

    return {
      'availableCount': availableCount,
      'soldCount': soldCount,
      'availableValue': availableValue,
      'soldThisMonth': soldThisMonth,
      'profit': profit,
      'pendingPaymentsAmount': pendingPaymentsAmount,
    };
  }

  void _navigateToItemsList(BuildContext context, bool soldStatus) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilteredItemsScreen(
          isSold: soldStatus,
          shopkeeperName: widget.shopkeeperName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reports for ${widget.shopkeeperName}")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchStats(widget.shopkeeperName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final stats = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: "Available Items",
                        value: stats['availableCount'].toString(),
                        icon: Icons.inventory_2_outlined,
                        color: Colors.green,
                        onTap: () => _navigateToItemsList(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: "Sold Items",
                        value: stats['soldCount'].toString(),
                        icon: Icons.sell,
                        color: Colors.orange,
                        onTap: () => _navigateToItemsList(context, true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: "Available Value",
                        value: "₹${stats['availableValue'].toStringAsFixed(2)}",
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: "Sold This Month",
                        value: stats['soldThisMonth'].toString(),
                        icon: Icons.calendar_today,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: "Pending Payments",
                        value: "₹${stats['pendingPaymentsAmount'].toStringAsFixed(2)}",
                        icon: Icons.pending_actions,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                    child: _buildStatCard(
                        title: "Total Profit",
                        value: "₹${stats['profit'].toStringAsFixed(2)}",
                        icon: Icons.trending_up,
                        color: Colors.teal,
                      ),
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
    final card = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: card)
        : card;
  }
}
