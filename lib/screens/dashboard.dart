import 'package:flutter/material.dart';
import 'package:smart_plaza/screens/add_item_screen.dart';
import 'package:smart_plaza/screens/all_items_screen.dart';
import 'package:smart_plaza/screens/reports_screen.dart';
import 'package:smart_plaza/screens/sell_item_screen.dart';

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background wrapper
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40), // status bar spacer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: const [
                  Icon(Icons.dashboard, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Smart Plaza Dashboard",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildDashboardButton(
                      context,
                      "Add Item",
                      Icons.add_circle_outline,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddItemScreen()),
                      ),
                    ),
                    _buildDashboardButton(
                      context,
                      "Sell Item",
                      Icons.point_of_sale,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AllItemsScreen(
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
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AllItemsScreen()),
                      ),
                    ),
                    _buildDashboardButton(
                      context,
                      "Reports",
                      Icons.bar_chart,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReportsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.deepPurple.withOpacity(0.2),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.deepPurple.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 50, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
