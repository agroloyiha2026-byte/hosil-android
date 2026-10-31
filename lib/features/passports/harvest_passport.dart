class HarvestPassport {
  final String id;
  final String? productId;
  final DateTime issuedAt;
  final DateTime? revokedAt;
  final String productTitle;
  final String productType;
  final String category;
  final String region;
  final String farmerName;
  final String farmerRegion;
  final bool productPublic;

  const HarvestPassport({
    required this.id,
    required this.productId,
    required this.issuedAt,
    required this.productTitle,
    required this.productType,
    required this.category,
    required this.region,
    required this.farmerName,
    required this.farmerRegion,
    required this.productPublic,
    this.revokedAt,
  });

  bool get revoked => revokedAt != null;

  factory HarvestPassport.fromMap(Map<String, dynamic> map) => HarvestPassport(
        id: map['id'] as String,
        productId: map['product_id'] as String?,
        issuedAt: DateTime.parse(map['issued_at'] as String),
        revokedAt: map['revoked_at'] == null ? null : DateTime.parse(map['revoked_at'] as String),
        productTitle: map['product_title'] as String? ?? '',
        productType: map['product_type'] as String? ?? '',
        category: map['category'] as String? ?? '',
        region: map['product_region'] as String? ?? '',
        farmerName: map['farmer_name'] as String? ?? '',
        farmerRegion: map['farmer_region'] as String? ?? '',
        productPublic: map['product_public'] as bool? ?? false,
      );
}
