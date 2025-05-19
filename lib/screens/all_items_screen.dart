import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllItemsScreen extends StatelessWidget {
  final bool showOnlyUnsold;
  final Function(String, Map<String, dynamic>)? onItemSelect;

  AllItemsScreen({this.showOnlyUnsold = false,this.onItemSelect});

  @override
  Widget build(BuildContext context) {
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
                if (index == 0 && availableItems.isNotEmpty) {
                  headerText = 'Available Items';
                } else if (index == availableItems.length && soldPendingPaymentItems.isNotEmpty) {
                  headerText = 'Sold - Payment Pending';
                } else {
                  headerText = 'Sold - Paid';
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
                    _buildItemCard(doc, data, isSold, isPaid),
                  ],
                );
              }

              return _buildItemCard(doc, data, isSold, isPaid);
            },
          );
        },
      ),
    );
  }

  Widget _buildItemCard(QueryDocumentSnapshot doc, Map<String, dynamic> data, bool isSold, bool isPaid) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () {
          if (onItemSelect != null) {
            onItemSelect!(doc.id, data);
          }
        },
        title: Text(data['name'] ?? 'Unnamed Item', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMEI: ${data['imei'] ?? '-'}'),
            Text('Purchase Price: ₹${data['purchasePrice'] ?? '-'}'),
            Row(
              children: [
                Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  Text('Payment Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }
}