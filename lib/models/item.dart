class Item {
  final String name;
  final String imei;
  final String color;
  final double purchasePrice;
  final String purchaseDate;
  final String purchaseParty;
  final double sellingPrice;
    final String sellingDate;
    final String sellingParty;
    final String remarks;
    final String scan;
    final String image;

  // Add other fields...

  Item({
    required this.name,
    required this.imei,
    required this.color,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.purchaseParty,
    required this.sellingPrice,
    required this.sellingDate,
    required this.sellingParty,
    required this.remarks,

    // ...other fields
  });
}