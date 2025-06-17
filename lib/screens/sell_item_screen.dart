import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase logout
import 'package:intl/intl.dart'; // Make sure intl is in pubspec.yaml

class SellItemScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const SellItemScreen({
    Key? key,
    required this.itemId,
    required this.itemData,
  }) : super(key: key);

  @override
  _SellItemScreenState createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final _sellPriceController = TextEditingController();
  final _sellDateController = TextEditingController();
  final _sellPartyController = TextEditingController();
  final _remarksController = TextEditingController();

  final _paymentDateController = TextEditingController();
  final _paymentRemarksController = TextEditingController();

  String? _selectedPaymentMode;

  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');


  String? userRole;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.data()?['role'];
      setState(() {
        userRole = role;
      });

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final isSold = widget.itemData['isSold'] == true;
      final shopkeeperId = (widget.itemData['shopkeeper'] as Map?)?['id'];

      if (isSold || (role == 'shopkeeper' && shopkeeperId != currentUserId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
          final message = isSold
              ? 'This item is already sold.'
              : 'You are not authorized to sell this item.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        });
      } else {
        // Initialize payment and remarks fields from existing data (if any)
        _remarksController.text = widget.itemData['remarks'] ?? '';
        _selectedPaymentMode = widget.itemData['paymentMode'];
        _paymentDateController.text = widget.itemData['paymentDate'] ?? '';
        _paymentRemarksController.text = widget.itemData['paymentRemarks'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _sellPriceController.dispose();
    _sellDateController.dispose();
    _sellPartyController.dispose();
    _remarksController.dispose();
    _paymentDateController.dispose();
    _paymentRemarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initialDate = _dateFormatter.parse(controller.text);
      } catch (_) {}
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      controller.text = _dateFormatter.format(date);
    }
  }

  Future<void> _sellItem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Prepare update data map
      Map<String, dynamic> updateData = {
        'sellPrice': double.parse(_sellPriceController.text),
        'sellDate': _sellDateController.text,
        'sellParty': _sellPartyController.text,
        'remarks': _remarksController.text,
        'isSold': true,
        'soldAt': FieldValue.serverTimestamp(),
      };

      // Optional payment info
      if (_selectedPaymentMode != null && _selectedPaymentMode!.isNotEmpty) {
        updateData.addAll({
          'paymentMode': _selectedPaymentMode,
          'paymentDate': _paymentDateController.text,
          'paymentRemarks': _paymentRemarksController.text,
        });
      }

      await _firestore.collection('inventory').doc(widget.itemId).update(updateData);

      Navigator.pop(context, true); // Return true to indicate sold
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    if (userRole == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invalid Role')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sell Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Info
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item: ${widget.itemData['name'] ?? 'Unnamed'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('IMEI: ${widget.itemData['imei'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),

              // Sell Details
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sell Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Sell Price*',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
                          final n = num.tryParse(value);
                          if (n == null) return 'Enter a valid number';
                          if (n <= 0) return 'Price must be greater than zero';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellDateController,
                        decoration: const InputDecoration(
                          labelText: 'Sell Date*',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _pickDate(_sellDateController),
                        validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellPartyController,
                        decoration: const InputDecoration(
                          labelText: 'Sell Party*',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              if (userRole == 'owner')
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Information (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Payment Mode',
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: ['Cash', 'UPI', 'Card', 'Other']
                              .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                              .toList(),
                          value: _selectedPaymentMode,
                          onChanged: (val) => setState(() => _selectedPaymentMode = val),
                          isExpanded: true,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paymentDateController,
                          decoration: const InputDecoration(
                            labelText: 'Payment Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _pickDate(_paymentDateController),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paymentRemarksController,
                          decoration: const InputDecoration(
                            labelText: 'Payment Remarks',
                            prefixIcon: Icon(Icons.note_add),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),

              // Sell Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sellItem,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Sell Item', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
