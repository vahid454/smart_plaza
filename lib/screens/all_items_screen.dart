import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class AllItemsScreen extends StatefulWidget {
  final bool showOnlyUnsold;
  final Function(String, Map<String, dynamic>)? onItemSelect;

  AllItemsScreen({this.showOnlyUnsold = false, this.onItemSelect});

  @override
  _AllItemsScreenState createState() => _AllItemsScreenState();
}

class _AllItemsScreenState extends State<AllItemsScreen> {
  List<QueryDocumentSnapshot> _allItems = [];

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
        final isOwner = role == 'owner';

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.showOnlyUnsold ? 'Sell Item - Select Unsold Item' : 'All Items'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _allItems.isEmpty ? null : () => _exportToExcel(context, _allItems),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: isShopkeeper
                ? FirebaseFirestore.instance.collection('inventory').snapshots()
                : isOwner
                    ? FirebaseFirestore.instance
                        .collection('inventory')
                        .where('ownerId', isEqualTo: currentUser?.uid)
                        .snapshots()
                    : FirebaseFirestore.instance.collection('inventory').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
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

              if (availableItems.isEmpty && soldPendingPaymentItems.isEmpty && soldPaidItems.isEmpty) {
                return const Center(child: Text('No items found'));
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

              // Update state only if the items list has changed
              if (mounted && (_allItems.length != allItems.length)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _allItems = allItems;
                    });
                  }
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
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
            } else if (widget.onItemSelect != null) {
              widget.onItemSelect!(doc.id, data);
            } else if (!isSold && widget.onItemSelect == null && !isShopkeeper) {
              _showChangeShopkeeperDialog(context, doc.id, data);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(data['name'] ?? 'Unnamed Item', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Icon(
                      isSold ? Icons.check_circle : Icons.shopping_bag_outlined,
                      color: isSold ? Colors.red : Colors.green,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IMEI: ${data['imei'] ?? '-'}'),
                    Text('Owner: ${data['ownerName'] ?? '-'}'),
                    Text('Shopkeeper: ${(data['shopkeeper'] as Map<String, dynamic>?)?['name'] ?? '-'}'),
                    Text('Purchase Price: ₹${data['purchasePrice'] ?? '-'}'),
                    if (isSold && data['saleDate'] != null) Text('Sold on: ${data['saleDate']}'),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      isSold ? 'Sold' : 'Available',
                      style: TextStyle(color: isSold ? Colors.red : Colors.green, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    if (isSold)
                      Row(
                        children: [
                          const Text('Payment: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            isPaid ? 'Paid' : 'Pending',
                            style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
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
void _exportToExcel(BuildContext context, List<QueryDocumentSnapshot> allItems) async {
  try {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Items'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: "#FFD966",
      fontColorHex: "#000000",
      horizontalAlign: HorizontalAlign.Center,
    );

    final dataRowHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: "#D9EAD3",
      fontColorHex: "#000000",
      horizontalAlign: HorizontalAlign.Center,
    );

    final rowStyle = CellStyle(
      backgroundColorHex: "#F2F2F2",
    );

    // Header rows
    sheet.appendRow(["iStocker"]);
    sheet.cell(CellIndex.indexByString("A1")).cellStyle = headerStyle;

    sheet.appendRow(["Empowering your inventory with intelligence"]);
    sheet.cell(CellIndex.indexByString("A2")).cellStyle = headerStyle;

    sheet.appendRow(["Generated On: ${DateTime.now()}"]);
    sheet.cell(CellIndex.indexByString("A3")).cellStyle = headerStyle;

    // Add 2-3 empty rows after subtitle and before column headings
    sheet.appendRow([]);
    sheet.appendRow([]);
    sheet.appendRow([]);
    
    // Column headings with clean background and bold font
    final headings = [
      'Name',
      'Serial Number',
      'Owner',
      'Shopkeeper',
      'Purchase Price',
      'Sold On',
      'Status',
      'Payment Mode',
      'Payment Date',
      'Payment Amount'
    ];
    sheet.appendRow(headings);
    for (int col = 0; col < headings.length; col++) {
      final colLetter = String.fromCharCode('A'.codeUnitAt(0) + col);
      final cell = sheet.cell(CellIndex.indexByString("${colLetter}6"));
      cell.cellStyle = dataRowHeaderStyle;
      sheet.setColWidth(col, 20); // Increase column width for better display
    }

    // Data rows
    bool alt = false;
    int dataRowIdx = 7; // Adjusted to start below heading row at index 6
    for (final doc in allItems) {
      final data = doc.data() as Map<String, dynamic>;
      final isSold = data['isSold'] ?? false;
      final row = [
        data['name'] ?? '',
        data['imei'] ?? '',
        data['ownerName'] ?? '',
        (data['shopkeeper'] as Map?)?['name'] ?? '',
        data['purchasePrice'] ?? '',
        isSold ? data['saleDate'] ?? '' : '',
        isSold ? 'Sold' : 'Available',
        data['paymentMode'] ?? '',
        data['paymentDate'] ?? '',
        data['paymentAmount'] ?? '',
      ];
      // Alternate row background color
      final altRowStyle = alt
          ? CellStyle(backgroundColorHex: "#FFFFFF")
          : rowStyle;
      sheet.appendRow(row);
      for (int col = 0; col < row.length; col++) {
        final colLetter = String.fromCharCode('A'.codeUnitAt(0) + col);
        sheet.cell(CellIndex.indexByString("$colLetter${dataRowIdx}")).cellStyle = altRowStyle;
      }
      alt = !alt;
      dataRowIdx++;
    }

    // Add 2–3 empty rows before the final footer message
    sheet.appendRow([]);
    sheet.appendRow([]);

    // Footer message
    final footerRowIdx = dataRowIdx + 3; // Set footerRowIdx accordingly
    sheet.appendRow(["Thank you for using iStocker ❤️"]);
    sheet.cell(CellIndex.indexByString("A${footerRowIdx}")).cellStyle = headerStyle;

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/all_items_export.xlsx');
      await file.writeAsBytes(fileBytes);
      OpenFile.open(file.path);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to export file: $e')),
    );
  }
}