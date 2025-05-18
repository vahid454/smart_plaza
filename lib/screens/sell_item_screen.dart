class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Smart Plaza Dashboard")),
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          _buildDashboardButton(context, "Add Item", Icons.add, () {}),
          _buildDashboardButton(context, "Sell Item", Icons.sell, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellItemScreen()))),
          _buildDashboardButton(context, "All Items", Icons.list, () {}),
          _buildDashboardButton(context, "Reports", Icons.analytics, () {}),
        ],
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}