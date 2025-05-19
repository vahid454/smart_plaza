import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllItemsScreen extends StatelessWidget {
  final Function(String, Map<String, dynamic>)? onItemSelect;

  AllItemsScreen({this.onItemSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Items")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isSold = data['isSold'] ?? false;

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
                      Text('Status: ${isSold ? 'Sold' : 'Available'}',
                          style: TextStyle(
                            color: isSold ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  trailing: Icon(
                    isSold ? Icons.check_circle : Icons.shopping_bag_outlined,
                    color: isSold ? Colors.red : Colors.green,
                    size: 28,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
