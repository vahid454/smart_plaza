import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellItemScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  SellItemScreen({required this.itemId, required this.itemData});

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

  // Payment info controllers
  final _paymentDateController = TextEditingController();
  final _paymentRemarksController = TextEditingController();

  String? _selectedPaymentMode;

  @override
  void initState() {
    super.initState();
    _remarksController.text = widget.itemData['remarks'] ?? '';
    // Optionally pre-fill payment info if present
    _selectedPaymentMode = widget.itemData['paymentMode'];
    _paymentDateController.text = widget.itemData['paymentDate'] ?? '';
    _paymentRemarksController.text = widget.itemData['paymentRemarks'] ?? '';
  }

  Future<void> _sellItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        Map<String, dynamic> updateData = {
          'sellPrice': double.parse(_sellPriceController.text),
          'sellDate': _sellDateController.text,
          'sellParty': _sellPartyController.text,
          'remarks': _remarksController.text,
          'isSold': true,
          'soldAt': FieldValue.serverTimestamp(),
        };

        // Add payment info only if payment mode is selected
        if (_selectedPaymentMode != null && _selectedPaymentMode!.isNotEmpty) {
          updateData.addAll({
            'paymentMode': _selectedPaymentMode,
            'paymentDate': _paymentDateController.text,
            'paymentRemarks': _paymentRemarksController.text,
          });
        }

        await _firestore.collection('inventory').doc(widget.itemId).update(updateData);

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      controller.text = '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item: ${widget.itemData['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('IMEI: ${widget.itemData['imei']}'),
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
                        decoration: const InputDecoration(labelText: 'Sell Price*', prefixIcon: Icon(Icons.attach_money)),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellDateController,
                        decoration: const InputDecoration(labelText: 'Sell Date*', prefixIcon: Icon(Icons.calendar_today)),
                        readOnly: true,
                        onTap: () => _pickDate(_sellDateController),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sellPartyController,
                        decoration: const InputDecoration(labelText: 'Sell Party*', prefixIcon: Icon(Icons.person)),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: 'Remarks', prefixIcon: Icon(Icons.notes)),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Payment Info (optional)
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
                        decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment)),
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
                        decoration: const InputDecoration(labelText: 'Payment Date', prefixIcon: Icon(Icons.calendar_today)),
                        readOnly: true,
                        onTap: () => _pickDate(_paymentDateController),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentRemarksController,
                        decoration: const InputDecoration(labelText: 'Payment Remarks', prefixIcon: Icon(Icons.note_add)),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

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
}
