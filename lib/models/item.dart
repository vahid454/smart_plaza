
// Your existing Item class with isSold getter
class Item {
  final String? id;
  final String? name;
  final String? imei;
  final String? color;
  final double? purchasePrice;
  final String? purchaseDate;
  final String? purchaseParty;
  final double? sellingPrice;
  final String? sellingDate;
  final String? sellingParty;
  final String? remarks;
  final String? scan;
  final String? image;
  final String? paymentMode;
  final String? paymentDate;
  final double? paymentAmount;
  final String? paymentRemarks;

  Item({
    this.id,
    this.name,
    this.imei,
    this.color,
    this.purchasePrice,
    this.purchaseDate,
    this.purchaseParty,
    this.sellingPrice,
    this.sellingDate,
    this.sellingParty,
    this.remarks,
    this.scan,
    this.image,
    this.paymentMode,
    this.paymentDate,
    this.paymentAmount,
    this.paymentRemarks,
  });

  bool get isSold => sellingDate != null;

  factory Item.fromMap(Map<String, dynamic> map, {String? id}) {
    return Item(
      id: id,
      name: map['name'] as String?,
      imei: map['imei'] as String?,
      color: map['color'] as String?,
      purchasePrice:
          (map['purchasePrice'] != null) ? (map['purchasePrice'] as num).toDouble() : null,
      purchaseDate: map['purchaseDate'] as String?,
      purchaseParty: map['purchaseParty'] as String?,
      sellingPrice:
          (map['sellingPrice'] != null) ? (map['sellingPrice'] as num).toDouble() : null,
      sellingDate: map['sellingDate'] as String?,
      sellingParty: map['sellingParty'] as String?,
      remarks: map['remarks'] as String?,
      scan: map['scan'] as String?,
      image: map['image'] as String?,
      paymentMode: map['paymentMode'] as String?,
      paymentDate: map['paymentDate'] as String?,
      paymentAmount:
          (map['paymentAmount'] != null) ? (map['paymentAmount'] as num).toDouble() : null,
      paymentRemarks: map['paymentRemarks'] as String?,
    );
  }
}

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imei': imei,
      'color': color,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate,
      'purchaseParty': purchaseParty,
      'sellingPrice': sellingPrice,
      'sellingDate': sellingDate,
      'sellingParty': sellingParty,
      'remarks': remarks,
      'scan': scan,
      'image': image,
      'paymentMode': paymentMode,
      'paymentDate': paymentDate,
      'paymentAmount': paymentAmount,
      'paymentRemarks': paymentRemarks,
    };
  }
}