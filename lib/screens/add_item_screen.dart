import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';


class AddItemScreen extends StatefulWidget {
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _imeiController = TextEditingController();
  final _colorController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _purchasePartyController = TextEditingController();
  final _remarksController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        await _firestore.collection('inventory').add({
          'name': _nameController.text.trim(),
          'imei': _imeiController.text.trim(),
          'color': _colorController.text.trim(),
          'purchasePrice': double.parse(_purchasePriceController.text.trim()),
          'purchaseDate': _purchaseDateController.text.trim(),
          'purchaseParty': _purchasePartyController.text.trim(),
          'sellPrice': 0.0,
          'sellDate': '',
          'sellParty': '',
          'remarks': _remarksController.text.trim(),
          'imageUrl': '', // TODO: Upload image to Firebase Storage & get URL
          'createdAt': FieldValue.serverTimestamp(),
          'isSold': false,
        });
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
      child: Scaffold(
        appBar: AppBar(title: Text('Add New Item')),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Image picker with border and icon overlay
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null 
                        ? Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey[600])
                        : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 20, color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 30),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name *',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.trim().isEmpty ? 'Item name is required' : null,
                ),
                SizedBox(height: 16),

                // IMEI
                TextFormField(
                  controller: _imeiController,
                  decoration: InputDecoration(
                    labelText: 'IMEI Number',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),

                // Color
                TextFormField(
                  controller: _colorController,
                  decoration: InputDecoration(
                    labelText: 'Color',
                    prefixIcon: Icon(Icons.color_lens_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Purchase Price
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: InputDecoration(
                    labelText: 'Purchase Price *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Purchase price is required';
                    if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Purchase Date with date picker
                TextFormField(
                  controller: _purchaseDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Purchase Date',
                    prefixIcon: Icon(Icons.date_range),
                    border: OutlineInputBorder(),
                    hintText: 'Select purchase date',
                  ),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                ),
                SizedBox(height: 16),

                // Purchase Party
                TextFormField(
                  controller: _purchasePartyController,
                  decoration: InputDecoration(
                    labelText: 'Purchase Party',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),

                // Remarks
                TextFormField(
                  controller: _remarksController,
                  decoration: InputDecoration(
                    labelText: 'Remarks',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                SizedBox(height: 32),

                // Save button with loading indicator
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveItem,
                    child: _isSaving
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Save Item', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imeiController.dispose();
    _colorController.dispose();
    _purchasePriceController.dispose();
    _purchaseDateController.dispose();
    _purchasePartyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }
}
