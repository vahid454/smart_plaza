import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' as excel;
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
  bool _loading = true;

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
              // Step 1: Handle loader state based on snapshot and item readiness
              bool showLoading = false;
              List<QueryDocumentSnapshot> availableItems = [];
              List<QueryDocumentSnapshot> soldPendingPaymentItems = [];
              List<QueryDocumentSnapshot> soldPaidItems = [];
              List<QueryDocumentSnapshot> allItems = [];

              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                showLoading = true;
              } else {
                // Categorize items
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
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
                  // No items found, show empty state (no loader)
                  showLoading = false;
                  return const Center(child: Text('No items found'));
                }

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
                allItems = [
                  ...availableItems,
                  ...soldPendingPaymentItems,
                  ...soldPaidItems,
                ];

                // Step 2: Move _loading state handling here, update _allItems and _loading synchronously
                if (_allItems.isEmpty && allItems.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _allItems = allItems;
                        _loading = false;
                      });
                    }
                  });
                }
                // Show loader only if _loading is true and _allItems is empty (i.e., initial data not yet ready)
                showLoading = _loading && _allItems.isEmpty;
              }

              return Stack(
                children: [
                  ListView.builder(
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
                  ),
                  if (showLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
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
    final xls = excel.Excel.createExcel();
    xls.delete('Sheet1');
    final sheet = xls['Items'];

    // --- HEADER SECTION ---
    // Add top padding (2 empty rows, since Title goes to row 3)
    sheet.appendRow([]);
    sheet.appendRow([]);

    // Title row (A3:J3 merged)
    sheet.merge(excel.CellIndex.indexByString("A3"), excel.CellIndex.indexByString("J3"));
    sheet.cell(excel.CellIndex.indexByString("A3")).value = "iStocker";
    sheet.cell(excel.CellIndex.indexByString("A3")).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 18,
      horizontalAlign: excel.HorizontalAlign.Center,
      backgroundColorHex: "#FFD966",
    );

    // Subtitle row (A4:J4 merged)
    sheet.merge(excel.CellIndex.indexByString("A4"), excel.CellIndex.indexByString("J4"));
    sheet.cell(excel.CellIndex.indexByString("A4")).value = "Empowering your inventory with intelligence";
    sheet.cell(excel.CellIndex.indexByString("A4")).cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: excel.HorizontalAlign.Center,
      backgroundColorHex: "#FFE599",
    );

    // Generated On row (A5:J5 merged)
    sheet.merge(excel.CellIndex.indexByString("A5"), excel.CellIndex.indexByString("J5"));
    sheet.cell(excel.CellIndex.indexByString("A5")).value = "Generated On: ${DateTime.now()}";
    sheet.cell(excel.CellIndex.indexByString("A5")).cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      backgroundColorHex: "#D9D9D9",
    );


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
    // Style header row (row 8, index 8 since 1-based)
    for (int col = 0; col < headings.length; col++) {
      final colLetter = String.fromCharCode('A'.codeUnitAt(0) + col);
      final cell = sheet.cell(excel.CellIndex.indexByString("${colLetter}7"));
      cell.cellStyle = excel.CellStyle(
        bold: true,
        fontColorHex: "#222222",
        backgroundColorHex: "#FFE599",
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      sheet.setColWidth(col, 60);
    }

    // --- DATA ROWS ---
    bool alt = false;
    int dataRowIdx = 8; // Data starts at row 8(1-based)
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
      sheet.appendRow(row);
      // Alternate row shading
      final rowColor = alt ? "#FFFFFF" : "#F2F2F2";
      for (int col = 0; col < row.length; col++) {
        final colLetter = String.fromCharCode('A'.codeUnitAt(0) + col);
        sheet.cell(excel.CellIndex.indexByString("$colLetter${dataRowIdx}")).cellStyle = excel.CellStyle(
          backgroundColorHex: rowColor,
        );
      }
      alt = !alt;
      dataRowIdx++;
    }

    // --- FOOTER SECTION ---
    // Add spacing before footer
    sheet.appendRow([]);
  

    // Footer message (A$footerRowIdx:J$footerRowIdx merged)
    final footerRowIdx = dataRowIdx + 3;
    sheet.merge(excel.CellIndex.indexByString("A$footerRowIdx"), excel.CellIndex.indexByString("J$footerRowIdx"));
    sheet.cell(excel.CellIndex.indexByString("A$footerRowIdx")).value = "Thank you for using iStocker ❤️";
    sheet.cell(excel.CellIndex.indexByString("A$footerRowIdx")).cellStyle = excel.CellStyle(
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
      backgroundColorHex: "#FFD9E6",
    );

    final fileBytes = xls.encode();
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