import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase logout
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_plaza/screens/add_item_screen.dart';
import 'package:smart_plaza/screens/all_items_screen.dart';
import 'package:smart_plaza/screens/reports_screen.dart';
import 'package:smart_plaza/screens/sell_item_screen.dart';
import 'package:smart_plaza/screens/login_screen.dart';
import 'dart:ui'; 

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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
      setState(() {
        userRole = doc.data()?['role'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: userRole == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      children: userRole == 'owner'
                          ? [
                              _buildDashboardButton(
                                context,
                                "Add Item",
                                Icons.add_circle_outline,
                                Colors.deepPurple,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AddItemScreen()),
                                  );
                                },
                              ),
                              _buildDashboardButton(
                                context,
                                "Reports",
                                Icons.bar_chart,
                                Colors.orange,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ShopkeeperSelectionScreen()),
                                  );
                                },
                              ),
                              _buildDashboardButton(
                                context,
                                "Sell Item",
                                Icons.point_of_sale,
                                Colors.green,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AllItemsScreen(
                                        showOnlyUnsold: true,
                                        onItemSelect: (itemId, itemData) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SellItemScreen(
                                                itemId: itemId,
                                                itemData: itemData,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildDashboardButton(
                                context,
                                "All Items",
                                Icons.inventory_2,
                                Colors.blue,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AllItemsScreen()),
                                  );
                                },
                              ),
                            ]
                          : [
                              _buildDashboardButton(
                                context,
                                "Sell Item",
                                Icons.point_of_sale,
                                Colors.green,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AllItemsScreen(
                                        showOnlyUnsold: true,
                                        onItemSelect: (itemId, itemData) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SellItemScreen(
                                                itemId: itemId,
                                                itemData: itemData,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildDashboardButton(
                                context,
                                "All Items",
                                Icons.inventory_2,
                                Colors.blue,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AllItemsScreen()),
                                  );
                                },
                              ),
                              // _buildDashboardButton(
                              //   context,
                              //   "Owner Settings",
                              //   Icons.settings,
                              //   Colors.deepOrange,
                              //   () {
                              //     // Navigate to owner management screen (to be implemented)
                              //     ScaffoldMessenger.of(context).showSnackBar(
                              //       const SnackBar(content: Text("Owner Settings screen to be implemented.")),
                              //     );
                              //   },
                              // ),
                            ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout failed: ${e.toString()}")),
        );
      }
    }
  }

  Widget _buildDashboardButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        elevation: 6,
        color: Colors.white,
        shadowColor: color.withOpacity(0.2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: color.withOpacity(0.15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.08), color.withOpacity(0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 34, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
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
