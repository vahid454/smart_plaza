import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  final String role; // 'owner' or 'shopkeeper'

  const SignupScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final TextEditingController _ownerEmailController = TextEditingController();
  String? _selectedOwnerId;
  List<Map<String, dynamic>> _owners = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'shopkeeper') {
      _loadOwners();
    }
  }

  Future<void> _loadOwners() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .get();

    setState(() {
      _owners = snapshot.docs
          .map((doc) => {'id': doc.id, 'username': doc['username'] ?? 'Unknown'})
          .toList();
    });
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': widget.role,
        if (widget.role == 'shopkeeper') ...{
          'ownerEmail': _ownerEmailController.text.trim(),
          'ownerId': _selectedOwnerId,
        },
        'createdAt': Timestamp.now(),
      });

      await userCredential.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent. Please verify to login."),
        ),
      );

      Navigator.pop(context); // Back to login
    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";
      if (e.code == 'email-already-in-use') {
        message = "Email already in use";
      } else if (e.code == 'weak-password') {
        message = "Weak password";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign Up as ${widget.role.toUpperCase()}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: "Username"),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: "Phone"),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: "Password"),
                    obscureText: true,
                    validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(labelText: "Confirm Password"),
                    obscureText: true,
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  if (widget.role == 'shopkeeper') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerEmailController,
                      decoration: const InputDecoration(labelText: "Owner Email"),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                        value: _selectedOwnerId,
                        items: _owners.map<DropdownMenuItem<String>>((owner) {
                            return DropdownMenuItem<String>(
                            value: owner['id'] as String,
                            child: Text(owner['username'] ?? ''),
                            );
                        }).toList(),
                        decoration: const InputDecoration(labelText: "Select Owner"),
                        onChanged: (val) => setState(() => _selectedOwnerId = val),
                        validator: (val) => val == null ? 'Please select an owner' : null,
                        ),

                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Sign Up", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("← Back to Login"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
