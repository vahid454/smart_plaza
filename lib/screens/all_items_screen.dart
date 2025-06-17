import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllItemsScreen extends StatelessWidget {
  final bool showOnlyUnsold;
  final Function(String, Map<String, dynamic>)? onItemSelect;

  AllItemsScreen({this.showOnlyUnsold = false,this.onItemSelect});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final role = userData?['role'] ?? '';
        final isShopkeeper = role == 'shopkeeper';
        final shopkeeperId = currentUser?.uid;

        return Scaffold(
          appBar: AppBar(title: Text(showOnlyUnsold ? 'Sell Item - Select Unsold Item' : 'All Items')),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No items found'));
              }

              // Categorize items
              final List<QueryDocumentSnapshot> availableItems = [];
              final List<QueryDocumentSnapshot> soldPendingPaymentItems = [];
              final List<QueryDocumentSnapshot> soldPaidItems = [];

              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;

                // Filter for shopkeeper
                final docShopkeeperId = (data['shopkeeper'] as Map?)?['id'];
                if (isShopkeeper && docShopkeeperId != shopkeeperId) continue;

                final isSold = data['isSold'] ?? false;
                final paymentMode = data['paymentMode'] ?? '';
                final paymentDate = data['paymentDate'] ?? '';
                final isPaid = paymentMode.isNotEmpty && paymentDate.isNotEmpty;

                if (!isSold) {
                  availableItems.add(doc);
                } else if (isSold && !isPaid) {
                  soldPendingPaymentItems.add(doc);
                } else {
                  soldPaidItems.add(doc);
                }
              }

              // Sort sold items by date (assuming there's a 'saleDate' field)
              soldPendingPaymentItems.sort((a, b) {
                final aDate = (a.data() as Map<String, dynamic>)['saleDate'] ?? '';
                final bDate = (b.data() as Map<String, dynamic>)['saleDate'] ?? '';
                return bDate.compareTo(aDate); // Newest first
              });

              soldPaidItems.sort((a, b) {
                final aDate = (a.data() as Map<String, dynamic>)['saleDate'] ?? '';
                final bDate = (b.data() as Map<String, dynamic>)['saleDate'] ?? '';
                return bDate.compareTo(aDate); // Newest first
              });

              // Combine all items in the desired order
              final List<QueryDocumentSnapshot> allItems = [
                ...availableItems,
                ...soldPendingPaymentItems,
                ...soldPaidItems,
              ];

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final doc = allItems[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final isSold = data['isSold'] ?? false;
                  final paymentMode = data['paymentMode'] ?? '';
                  final paymentDate = data['paymentDate'] ?? '';
                  final isPaid = paymentMode.isNotEmpty && paymentDate.isNotEmpty;

                  // Add section headers
                  if (index == 0 || 
                      (index == availableItems.length && availableItems.isNotEmpty) || 
                      (index == availableItems.length + soldPendingPaymentItems.length && soldPendingPaymentItems.isNotEmpty)) {
                    String headerText;
                    bool isSoldPaidSection = false;
                    if (index == 0 && availableItems.isNotEmpty) {
                      headerText = 'Available Items';
                      isSoldPaidSection = false;
                    } else if (index == availableItems.length && soldPendingPaymentItems.isNotEmpty) {
                      headerText = 'Sold - Payment Pending';
                      isSoldPaidSection = false;
                    } else {
                      headerText = 'Sold - Paid';
                      isSoldPaidSection = true;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.grey[200],
                          child: Text(
                            headerText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        _buildItemCard(doc, data, isSold, isPaid, isSoldPaidSection: isSoldPaidSection, isShopkeeper: isShopkeeper),
                      ],
                    );
                  }

                  // Mark 'Sold - Paid' section items for gesture dialog
                  bool isSoldPaidSection = (index >= availableItems.length + soldPendingPaymentItems.length);
                  return _buildItemCard(doc, data, isSold, isPaid, isSoldPaidSection: isSoldPaidSection, isShopkeeper: isShopkeeper);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildItemCard(QueryDocumentSnapshot doc, Map<String, dynamic> data, bool isSold, bool isPaid, {bool isSoldPaidSection = false, bool isShopkeeper = false}) {
    return Builder(
      builder: (context) => Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: GestureDetector(
          onTap: () {
            if (isSoldPaidSection) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Payment Details"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Payment Mode: ${data['paymentMode'] ?? '-'}"),
                      Text("Payment Date: ${data['paymentDate'] ?? '-'}"),
                      Text("Payment Amount: ₹${data['paymentAmount'] ?? '-'}"),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            } else if (onItemSelect != null) {
              onItemSelect!(doc.id, data);
            } else if (!isSold && onItemSelect == null && !isShopkeeper) {
              _showChangeShopkeeperDialog(context, doc.id, data);
            }
          },
          child: ListTile(
            title: Text(data['name'] ?? 'Unnamed Item', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMEI: ${data['imei'] ?? '-'}'),
                Text('Owner: ${data['ownerName'] ?? '-'}'),
                Text('Shopkeeper: ${(data['shopkeeper'] as Map<String, dynamic>?)?['name'] ?? '-'}'),
                Text('Purchase Price: ₹${data['purchasePrice'] ?? '-'}'),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      isSold ? 'Sold' : 'Available',
                      style: TextStyle(
                        color: isSold ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isSold)
                  Row(
                    children: [
                      const Text('Payment Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        isPaid ? 'Paid' : 'Pending',
                        style: TextStyle(
                          color: isPaid ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (isSold && data['saleDate'] != null)
                  Text('Sold on: ${data['saleDate']}'),
              ],
            ),
            trailing: Icon(
              isSold ? Icons.check_circle : Icons.shopping_bag_outlined,
              color: isSold ? Colors.red : Colors.green,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

void _showChangeShopkeeperDialog(BuildContext context, String docId, Map<String, dynamic> data) async {
  final ownerId = data['ownerId'];
  final shopkeeperSnapshot = await FirebaseFirestore.instance.collection('users')
      .where('role', isEqualTo: 'shopkeeper')
      .where('ownerId', isEqualTo: ownerId)
      .get();

  final shopkeepers = shopkeeperSnapshot.docs.map((doc) => {
    'id': doc.id,
    'name': doc['username'] as String,
  }).toList();

  String selectedShopkeeperId = (data['shopkeeper'] as Map<String, dynamic>?)?['id'] ?? (shopkeepers.isNotEmpty ? shopkeepers.first['id']! : '');
  String selectedShopkeeperName = (data['shopkeeper'] as Map<String, dynamic>?)?['name'] ?? (shopkeepers.isNotEmpty ? shopkeepers.first['name']! : '');

  showDialog(
    context: context,
    builder: (context) {
      String dropdownValue = selectedShopkeeperId.isNotEmpty && shopkeepers.any((sk) => sk['id'] == selectedShopkeeperId)
          ? selectedShopkeeperId
          : (shopkeepers.isNotEmpty ? shopkeepers.first['id']! : '');
      String? selectedShopkeeperIdLocal = selectedShopkeeperId;
      String? selectedShopkeeperNameLocal = selectedShopkeeperName;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Shopkeeper'),
            content: DropdownButtonFormField<String>(
              value: dropdownValue.isNotEmpty && shopkeepers.any((sk) => sk['id'] == dropdownValue) ? dropdownValue : null,
              items: shopkeepers.map((shopkeeper) {
                return DropdownMenuItem<String>(
                  value: shopkeeper['id'],
                  child: Text(shopkeeper['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final sk = shopkeepers.firstWhere((s) => s['id'] == value);
                  setState(() {
                    dropdownValue = value;
                    selectedShopkeeperIdLocal = sk['id'];
                    selectedShopkeeperNameLocal = sk['name'];
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Select Shopkeeper'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (dropdownValue.isNotEmpty) {
                    await FirebaseFirestore.instance.collection('inventory').doc(docId).update({
                      'shopkeeper': {
                        'id': selectedShopkeeperIdLocal,
                        'name': selectedShopkeeperNameLocal,
                      },
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    },
  );
}