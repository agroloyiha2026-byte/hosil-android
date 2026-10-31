class ServiceListing {
  final String id,
      ownerId,
      serviceType,
      title,
      region,
      description,
      currency,
      status;
  final double? priceAmount;
  final String? priceUnit, contactPhone, imageUrl;

  const ServiceListing({
    required this.id,
    required this.ownerId,
    required this.serviceType,
    required this.title,
    required this.region,
    required this.description,
    required this.currency,
    required this.status,
    this.priceAmount,
    this.priceUnit,
    this.contactPhone,
    this.imageUrl,
  });

  factory ServiceListing.fromMap(Map<String, dynamic> map) => ServiceListing(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        serviceType: map['service_type'] as String,
        title: map['title'] as String,
        region: map['region'] as String,
        description: map['description'] as String,
        currency: map['currency'] as String,
        status: map['status'] as String,
        priceAmount: (map['price_amount'] as num?)?.toDouble(),
        priceUnit: map['price_unit'] as String?,
        contactPhone: map['contact_phone'] as String?,
        imageUrl: map['image_url'] as String?,
      );
}
