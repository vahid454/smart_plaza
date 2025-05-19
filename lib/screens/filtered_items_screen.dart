import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FilteredItemsScreen extends StatelessWidget {
  final bool isSold;

  const FilteredItemsScreen({super.key, required this.isSold});

  void _showPaymentDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final TextEditingController paymentDateController =
        TextEditingController(text: data['paymentDate'] ?? '');
    final TextEditingController paymentAmountController =
        TextEditingController(
            text: (data['paymentAmount'] ?? '').toString());

    String selectedPaymentMode = data['paymentMode'] ?? 'Cash';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Update Payment Details"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPaymentMode,
                  decoration: const InputDecoration(labelText: "Payment Mode"),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedPaymentMode = value;
                    }
                  },
                ),
                TextField(
                  controller: paymentDateController,
                  decoration: const InputDecoration(labelText: "Payment Date (yyyy-MM-dd)"),
                  readOnly: true,
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      paymentDateController.text =
                          DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                ),
                TextField(
                  controller: paymentAmountController,
                  decoration: const InputDecoration(labelText: "Payment Amount"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('inventory')
                    .doc(doc.id)
                    .update({
                  'paymentMode': selectedPaymentMode,
                  'paymentDate': paymentDateController.text.trim(),
                  'paymentAmount':
                      double.tryParse(paymentAmountController.text.trim()) ?? 0,
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSold ? "Sold Items" : "Available Items"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .where('isSold', isEqualTo: isSold)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found'));
          }

          List<QueryDocumentSnapshot> items = [];

          if (isSold) {
            final pendingItems = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final paymentMode = data['paymentMode'] ?? '';
              final paymentDate = data['paymentDate'] ?? '';
              return paymentMode.isEmpty || paymentDate.isEmpty;
            }).toList();

            final paidItems = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final paymentMode = data['paymentMode'] ?? '';
              final paymentDate = data['paymentDate'] ?? '';
              return paymentMode.isNotEmpty && paymentDate.isNotEmpty;
            }).toList();

            paidItems.sort((a, b) {
              final aDate = (a.data() as Map<String, dynamic>)['paymentDate'] ?? '';
              final bDate = (b.data() as Map<String, dynamic>)['paymentDate'] ?? '';
              return bDate.compareTo(aDate);
            });

            items = [...pendingItems, ...paidItems];
          } else {
            items = snapshot.data!.docs.toList();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              final paymentMode = data['paymentMode'] ?? '';
              final paymentDate = data['paymentDate'] ?? '';
              final paymentAmount = data['paymentAmount'] ?? 0;
              final isPaid = paymentMode.isNotEmpty && paymentDate.isNotEmpty;

              if (isSold &&
                  (index == 0 ||
                      index ==
                          items.indexWhere((d) {
                            final dData = d.data() as Map<String, dynamic>;
                            return (dData['paymentMode'] ?? '').isNotEmpty &&
                                (dData['paymentDate'] ?? '').isNotEmpty;
                          }))) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.grey[200],
                      child: Text(
                        index == 0 ? 'Pending Payment' : 'Paid Items',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    _buildItemCard(context, doc, data, isPaid),
                  ],
                );
              }

              return _buildItemCard(context, doc, data, isPaid);
            },
          );
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, QueryDocumentSnapshot doc,
      Map<String, dynamic> data, bool isPaid) {
    final paymentMode = data['paymentMode'] ?? '';
    final paymentDate = data['paymentDate'] ?? '';
    final paymentAmount = data['paymentAmount'] ?? 0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () {
          if (isSold) {
            _showPaymentDialog(context, doc);
          }
        },
        title: Text(
          data['name'] ?? 'Unnamed Item',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IMEI: ${data['imei'] ?? '-'}'),
            Text('Purchase Price: ₹${data['purchasePrice'] ?? '-'}'),
            if (isSold) ...[
              const SizedBox(height: 4),
              Text('Selling Price: ₹${data['sellingPrice'] ?? '-'}'),
              Row(
                children: [
                  const Text('Payment Status: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    isPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (isPaid) ...[
                Text('Mode: $paymentMode'),
                Text('Date: $paymentDate'),
                Text('Amount: ₹$paymentAmount'),
              ]
            ],
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
