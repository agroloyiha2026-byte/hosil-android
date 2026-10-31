import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';

class AgroCategory {
  final String slug, nameUz, nameRu, nameEn;
  final bool active;
  final int sortOrder;
  const AgroCategory(this.slug, this.nameUz, this.nameRu, this.nameEn,
      {this.active = true, this.sortOrder = 0});
  factory AgroCategory.fromMap(Map<String, dynamic> row) => AgroCategory(
      row['slug'] as String,
      row['name_uz'] as String,
      row['name_ru'] as String,
      row['name_en'] as String,
      active: row['active'] as bool? ?? true,
      sortOrder: row['sort_order'] as int? ?? 0);
  String name(String lang) => lang == 'ru'
      ? nameRu
      : lang == 'en'
          ? nameEn
          : nameUz;
}

class AgroReport {
  final String id, storeId, reason, status;
  final String? productId, storeName, productName;
  final DateTime createdAt;
  const AgroReport(
      this.id, this.storeId, this.reason, this.status, this.createdAt,
      {this.productId, this.storeName, this.productName});
  factory AgroReport.fromMap(Map<String, dynamic> row) {
    final store = row['store'];
    final product = row['product'];
    return AgroReport(
      row['id'] as String,
      row['store_id'] as String,
      row['reason'] as String,
      row['status'] as String,
      DateTime.parse(row['created_at'] as String),
      productId: row['product_id'] as String?,
      storeName:
          store is Map<String, dynamic> ? store['name'] as String? : null,
      productName:
          product is Map<String, dynamic> ? product['title'] as String? : null,
    );
  }
}

class AgroStore {
  final String id, ownerId, name, phone, region, address, status;
  final String? district,
      openingHours,
      imageUrl,
      description,
      deliveryArea,
      orderInfo,
      adminNote;
  final String? companyName, responsiblePerson, email, legalDocumentUrl;
  final double? latitude, longitude;
  final int productCount;
  final bool locationPublic, deliveryEnabled, verified;
  const AgroStore({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.phone,
    required this.region,
    required this.address,
    required this.status,
    required this.locationPublic,
    required this.deliveryEnabled,
    required this.verified,
    this.district,
    this.openingHours,
    this.imageUrl,
    this.description,
    this.deliveryArea,
    this.orderInfo,
    this.latitude,
    this.longitude,
    this.adminNote,
    this.companyName,
    this.responsiblePerson,
    this.email,
    this.legalDocumentUrl,
    this.productCount = 0,
  });
  factory AgroStore.fromMap(Map<String, dynamic> row) {
    final private = row['private'];
    return AgroStore(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String? ?? '',
      name: row['name'] as String,
      phone: row['phone'] as String,
      region: row['region'] as String,
      address: row['address'] as String,
      status: row['status'] as String,
      locationPublic: row['location_public'] as bool? ?? false,
      deliveryEnabled: row['delivery_enabled'] as bool? ?? false,
      verified: row['is_verified'] as bool? ?? false,
      district: row['district'] as String?,
      openingHours: row['opening_hours'] as String?,
      imageUrl: row['image_url'] as String?,
      description: row['description'] as String?,
      deliveryArea: row['delivery_area'] as String?,
      orderInfo: row['order_info'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      adminNote: row['admin_note'] as String?,
      companyName: private is Map<String, dynamic>
          ? private['company_name'] as String?
          : null,
      responsiblePerson: private is Map<String, dynamic>
          ? private['responsible_person'] as String?
          : null,
      email:
          private is Map<String, dynamic> ? private['email'] as String? : null,
      legalDocumentUrl: private is Map<String, dynamic>
          ? private['legal_document_url'] as String?
          : null,
    );
  }

  AgroStore withProductCount(int count) => AgroStore(
        id: id,
        ownerId: ownerId,
        name: name,
        phone: phone,
        region: region,
        address: address,
        status: status,
        locationPublic: locationPublic,
        deliveryEnabled: deliveryEnabled,
        verified: verified,
        district: district,
        openingHours: openingHours,
        imageUrl: imageUrl,
        description: description,
        deliveryArea: deliveryArea,
        orderInfo: orderInfo,
        latitude: latitude,
        longitude: longitude,
        adminNote: adminNote,
        companyName: companyName,
        responsiblePerson: responsiblePerson,
        email: email,
        legalDocumentUrl: legalDocumentUrl,
        productCount: count,
      );
}

class AgroProduct {
  final String id, storeId, title, category, currency, unit;
  final double price, stock;
  final String? description,
      imageUrl,
      manufacturer,
      packageSize,
      activeIngredient,
      instructionsUrl,
      storageConditions,
      safetyWarning,
      moderationStatus;
  final String? moderationNote;
  final String? expiryDate;
  final AgroStore? store;
  final bool published;
  const AgroProduct({
    required this.id,
    required this.storeId,
    required this.title,
    required this.category,
    required this.currency,
    required this.unit,
    required this.price,
    required this.stock,
    this.description,
    this.imageUrl,
    this.manufacturer,
    this.packageSize,
    this.activeIngredient,
    this.instructionsUrl,
    this.storageConditions,
    this.safetyWarning,
    this.moderationStatus,
    this.store,
    this.published = false,
    this.expiryDate,
    this.moderationNote,
  });
  factory AgroProduct.fromMap(Map<String, dynamic> row) {
    final storeMap = row['store'];
    return AgroProduct(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      title: row['title'] as String,
      category: row['category'] as String,
      currency: row['currency'] as String,
      unit: row['unit'] as String,
      price: (row['price'] as num).toDouble(),
      stock: (row['stock'] as num).toDouble(),
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      manufacturer: row['manufacturer'] as String?,
      packageSize: row['package_size'] as String?,
      activeIngredient: row['active_ingredient'] as String?,
      instructionsUrl: row['instructions_url'] as String?,
      storageConditions: row['storage_conditions'] as String?,
      safetyWarning: row['safety_warning'] as String?,
      moderationStatus: row['moderation_status'] as String?,
      moderationNote: row['moderation_note'] as String?,
      published: row['published'] as bool? ?? false,
      expiryDate: row['expiry_date'] as String?,
      store:
          storeMap is Map<String, dynamic> ? AgroStore.fromMap(storeMap) : null,
    );
  }
}

class AgroInquiry {
  final String id, productId, customerId, status;
  final String storeId;
  final double quantity;
  final String? message;
  final DateTime createdAt;
  const AgroInquiry(this.id, this.storeId, this.productId, this.customerId,
      this.status, this.quantity, this.message, this.createdAt);
  factory AgroInquiry.fromMap(Map<String, dynamic> row) => AgroInquiry(
        row['id'] as String,
        row['store_id'] as String,
        row['product_id'] as String,
        row['customer_id'] as String,
        row['status'] as String,
        (row['quantity'] as num).toDouble(),
        row['message'] as String?,
        DateTime.parse(row['created_at'] as String),
      );
}

class AgroInquiryMessage {
  final String id, senderId, body;
  final DateTime createdAt;
  const AgroInquiryMessage(this.id, this.senderId, this.body, this.createdAt);
  factory AgroInquiryMessage.fromMap(Map<String, dynamic> row) =>
      AgroInquiryMessage(
        row['id'] as String,
        row['sender_id'] as String,
        row['body'] as String,
        DateTime.parse(row['created_at'] as String),
      );
}

class AgroaptekaRepository {
  SupabaseClient get _client {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  static const _storeColumns =
      'id,owner_id,name,phone,region,district,address,latitude,longitude,location_public,opening_hours,image_url,description,delivery_enabled,delivery_area,order_info,status,is_verified';
  static const _publicStoreColumns =
      'id,name,phone,region,district,address,latitude,longitude,location_public,opening_hours,image_url,description,delivery_enabled,delivery_area,order_info,status,is_verified';
  static const _productColumns =
      'id,store_id,title,category,description,image_url,price,currency,unit,stock,manufacturer,package_size,expiry_date,active_ingredient,instructions_url,storage_conditions,safety_warning,moderation_status,published';
  static const _ownerProductColumns = '$_productColumns,moderation_note';
  static const _adminStoreColumns =
      '$_storeColumns,private:agroapteka_store_private(company_name,responsible_person,email,legal_document_url)';
  static const _adminProductColumns = '$_productColumns,moderation_note';

  Future<List<AgroCategory>> categories() async {
    final rows = await _client
        .from('agroapteka_categories')
        .select()
        .eq('active', true)
        .order('sort_order');
    return (rows as List)
        .map((r) => AgroCategory.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgroCategory>> adminCategories() async {
    final rows = await _client
        .from('agroapteka_categories')
        .select()
        .order('sort_order');
    return (rows as List)
        .map((r) => AgroCategory.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCategory({
    required String slug,
    required String nameUz,
    required String nameRu,
    required String nameEn,
    required int sortOrder,
    bool active = true,
  }) async {
    final normalized = slug.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(normalized) ||
        nameUz.trim().isEmpty ||
        nameRu.trim().isEmpty ||
        nameEn.trim().isEmpty) {
      throw const FormatException('invalid_category');
    }
    await _client.from('agroapteka_categories').upsert({
      'slug': normalized,
      'name_uz': nameUz.trim(),
      'name_ru': nameRu.trim(),
      'name_en': nameEn.trim(),
      'sort_order': sortOrder,
      'active': active,
    });
  }

  Future<void> setCategoryActive(String slug, bool active) async => _client
      .from('agroapteka_categories')
      .update({'active': active}).eq('slug', slug);

  Future<List<AgroStore>> stores(
      {String region = '',
      bool delivery = false,
      bool verifiedOnly = false}) async {
    var query = _client
        .from('agroapteka_stores')
        .select(_publicStoreColumns)
        .eq('status', 'approved')
        .eq('is_verified', true);
    if (region.trim().isNotEmpty)
      query = query.ilike('region', '%${_clean(region)}%');
    if (delivery) query = query.eq('delivery_enabled', true);
    if (verifiedOnly) query = query.eq('is_verified', true);
    final rows = await query.order('name').limit(100);
    final stores = (rows as List)
        .map((r) => AgroStore.fromMap(r as Map<String, dynamic>))
        .toList();
    if (stores.isEmpty) return stores;
    final productRows = await _client
        .from('agroapteka_products')
        .select('store_id')
        .eq('published', true)
        .eq('moderation_status', 'approved')
        .inFilter('store_id', stores.map((store) => store.id).toList());
    final counts = <String, int>{};
    for (final row in productRows as List) {
      final storeId = (row as Map<String, dynamic>)['store_id'] as String;
      counts.update(storeId, (count) => count + 1, ifAbsent: () => 1);
    }
    return stores
        .map((store) => store.withProductCount(counts[store.id] ?? 0))
        .toList();
  }

  Future<AgroStore?> publicStore(String id) async {
    final row = await _client
        .from('agroapteka_stores')
        .select(_publicStoreColumns)
        .eq('id', id)
        .eq('status', 'approved')
        .eq('is_verified', true)
        .maybeSingle();
    return row == null ? null : AgroStore.fromMap(row);
  }

  Future<List<AgroProduct>> products({
    String queryText = '',
    String? category,
    String region = '',
    String? currency,
    double? minPrice,
    double? maxPrice,
    bool inStock = false,
    bool delivery = false,
  }) async {
    var query = _client
        .from('agroapteka_products')
        .select(
          '$_productColumns,store:agroapteka_stores!inner($_publicStoreColumns)',
        )
        .eq('published', true)
        .eq('moderation_status', 'approved')
        .eq('store.status', 'approved')
        .eq('store.is_verified', true);
    if (category != null) query = query.eq('category', category);
    if (currency != null) query = query.eq('currency', currency);
    if (region.trim().isNotEmpty)
      query = query.ilike('store.region', '%${_clean(region)}%');
    if (minPrice != null) query = query.gte('price', minPrice);
    if (maxPrice != null) query = query.lte('price', maxPrice);
    if (inStock) query = query.gt('stock', 0);
    if (delivery) query = query.eq('store.delivery_enabled', true);
    final cleaned = _clean(queryText);
    if (cleaned.isNotEmpty) query = query.ilike('title', '%$cleaned%');
    final rows = await query.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((r) => AgroProduct.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<AgroStore?> ownStore(String ownerId) async {
    final row = await _client
        .from('agroapteka_stores')
        .select(_storeColumns)
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null ? null : AgroStore.fromMap(row);
  }

  Future<List<Map<String, dynamic>>> privateStore(String storeId) async {
    final rows = await _client
        .from('agroapteka_store_private')
        .select(
          'company_name,responsible_person,email,legal_document_url,latitude,longitude,admin_note',
        )
        .eq('store_id', storeId)
        .limit(1);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveStore({
    required String? storeId,
    required String ownerId,
    required String name,
    required String phone,
    required String region,
    required String district,
    required String address,
    required String latitude,
    required String longitude,
    required bool locationPublic,
    required String openingHours,
    required String imageUrl,
    required String description,
    required bool deliveryEnabled,
    required String deliveryArea,
    required String orderInfo,
    required String companyName,
    required String responsiblePerson,
    required String email,
    required String legalDocumentUrl,
  }) async {
    final lat = _numberOrNull(latitude), lon = _numberOrNull(longitude);
    if ((latitude.trim().isNotEmpty && (lat == null || !lat.isFinite)) ||
        (longitude.trim().isNotEmpty && (lon == null || !lon.isFinite)) ||
        (lat != null && (lat < -90 || lat > 90)) ||
        (lon != null && (lon < -180 || lon > 180))) {
      throw const FormatException('invalid_coordinates');
    }
    if ((lat == null) != (lon == null))
      throw const FormatException('coordinates_incomplete');
    if (locationPublic && lat == null)
      throw const FormatException('coordinates_required');
    final row = await _client
        .from('agroapteka_stores')
        .upsert({
          if (storeId != null) 'id': storeId,
          'owner_id': ownerId,
          'name': name.trim(),
          'phone': phone.trim(),
          'region': region.trim(),
          'district': _nullable(district),
          'address': address.trim(),
          'latitude': lat,
          'longitude': lon,
          'location_public': locationPublic,
          'opening_hours': _nullable(openingHours),
          'image_url': _nullable(imageUrl),
          'description': _nullable(description),
          'delivery_enabled': deliveryEnabled,
          'delivery_area': _nullable(deliveryArea),
          'order_info': _nullable(orderInfo),
        }, onConflict: 'owner_id')
        .select('id')
        .single();
    await _client.from('agroapteka_store_private').upsert({
      'store_id': row['id'],
      'owner_id': ownerId,
      'company_name': _nullable(companyName),
      'responsible_person': _nullable(responsiblePerson),
      'email': _nullable(email),
      'legal_document_url': _nullable(legalDocumentUrl),
      'latitude': lat,
      'longitude': lon,
    }, onConflict: 'store_id');
  }

  Future<List<AgroProduct>> ownProducts(String storeId) async {
    final rows = await _client
        .from('agroapteka_products')
        .select(_ownerProductColumns)
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AgroProduct.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProduct({
    String? id,
    required String storeId,
    required String title,
    required String category,
    required String description,
    required String imageUrl,
    required String price,
    required String currency,
    required String unit,
    required String stock,
    required String manufacturer,
    required String packageSize,
    required String expiryDate,
    required String activeIngredient,
    required String instructionsUrl,
    required String storageConditions,
    required String safetyWarning,
  }) async {
    final amount = double.tryParse(price.replaceAll(',', '.'));
    final quantity = double.tryParse(stock.replaceAll(',', '.'));
    if (amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        quantity == null ||
        !quantity.isFinite ||
        quantity < 0) {
      throw const FormatException('invalid_price_stock');
    }
    DateTime? expiry;
    if (expiryDate.trim().isNotEmpty) {
      expiry = DateTime.tryParse(expiryDate.trim());
      if (expiry == null) throw const FormatException('invalid_expiry');
    }
    final data = {
      'store_id': storeId,
      'title': title.trim(),
      'category': category,
      'description': _nullable(description),
      'image_url': _nullable(imageUrl),
      'price': amount,
      'currency': currency,
      'unit': unit.trim(),
      'stock': quantity,
      'manufacturer': _nullable(manufacturer),
      'package_size': _nullable(packageSize),
      'expiry_date': expiry?.toIso8601String().substring(0, 10),
      'active_ingredient': _nullable(activeIngredient),
      'instructions_url': _nullable(instructionsUrl),
      'storage_conditions': _nullable(storageConditions),
      'safety_warning': _nullable(safetyWarning),
    };
    if (id == null) {
      await _client.from('agroapteka_products').insert(data);
    } else {
      await _client
          .from('agroapteka_products')
          .update(data)
          .eq('id', id)
          .eq('store_id', storeId);
    }
  }

  Future<void> setProductPublished(String id, bool published) async => _client
      .from('agroapteka_products')
      .update({'published': published}).eq('id', id);

  Future<String> sendInquiry({
    required String storeId,
    required String productId,
    required String customerId,
    required double quantity,
    String? message,
  }) async {
    if (!quantity.isFinite || quantity <= 0)
      throw const FormatException('invalid_quantity');
    final row = await _client
        .from('agroapteka_inquiries')
        .insert({
          'store_id': storeId,
          'product_id': productId,
          'customer_id': customerId,
          'quantity': quantity,
          'message': _nullable(message),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<AgroInquiry>> ownInquiries(String storeId) async {
    final rows = await _client
        .from('agroapteka_inquiries')
        .select(
          'id,store_id,product_id,customer_id,status,quantity,message,created_at',
        )
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AgroInquiry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgroInquiry>> customerInquiries(String customerId) async {
    final rows = await _client
        .from('agroapteka_inquiries')
        .select(
          'id,store_id,product_id,customer_id,status,quantity,message,created_at',
        )
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AgroInquiry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgroInquiryMessage>> inquiryMessages(String inquiryId) async {
    final rows = await _client
        .from('agroapteka_inquiry_messages')
        .select(
          'id,inquiry_id,sender_id,body,created_at',
        )
        .eq('inquiry_id', inquiryId)
        .order('created_at')
        .limit(300);
    return (rows as List)
        .map((r) => AgroInquiryMessage.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendInquiryMessage(
      String inquiryId, String senderId, String body) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 4000)
      throw const FormatException('invalid_message');
    await _client.from('agroapteka_inquiry_messages').insert({
      'inquiry_id': inquiryId,
      'sender_id': senderId,
      'body': text,
    });
  }

  Future<void> updateInquiry(String id, String status) async {
    if (!const {'reviewing', 'accepted', 'rejected', 'completed'}
        .contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await _client
        .from('agroapteka_inquiries')
        .update({'status': status}).eq('id', id);
  }

  Future<List<AgroStore>> pendingStores() async {
    final rows = await _client
        .from('agroapteka_stores')
        .select(_storeColumns)
        .eq('status', 'pending')
        .order('created_at')
        .limit(100);
    return (rows as List)
        .map((r) => AgroStore.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgroStore>> allStores() async {
    final rows = await _client
        .from('agroapteka_stores')
        .select(_adminStoreColumns)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AgroStore.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgroProduct>> pendingProducts() async {
    final rows = await _client
        .from('agroapteka_products')
        .select(
          '$_adminProductColumns,store:agroapteka_stores!inner($_publicStoreColumns)',
        )
        .eq('moderation_status', 'pending')
        .order('created_at')
        .limit(100);
    return (rows as List)
        .map((r) => AgroProduct.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> reviewStore(String id, String status, String? note) =>
      _client.rpc('agroapteka_review_store', params: {
        'p_store_id': id,
        'p_status': status,
        'p_note': _nullable(note)
      });

  Future<void> reviewProduct(String id, String status, String? note) =>
      _client.rpc('agroapteka_moderate_product', params: {
        'p_product_id': id,
        'p_status': status,
        'p_note': _nullable(note)
      });

  Future<void> submitReport({
    required String storeId,
    String? productId,
    required String reporterId,
    required String reason,
  }) async {
    if (reason.trim().length < 5) throw const FormatException('invalid_report');
    await _client.from('agroapteka_reports').insert({
      'store_id': storeId,
      'product_id': productId,
      'reporter_id': reporterId,
      'reason': reason.trim(),
    });
  }

  Future<List<AgroReport>> openReports() async {
    final rows = await _client
        .from('agroapteka_reports')
        .select(
          'id,store_id,product_id,reason,status,created_at,store:agroapteka_stores(name),product:agroapteka_products(title)',
        )
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AgroReport.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveReport(String id, String note) async {
    await _client.from('agroapteka_reports').update({
      'status': 'resolved',
      'admin_note': _nullable(note),
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> moderationHistory() async {
    final rows = await _client
        .from('audit_logs')
        .select('action,entity,entity_id,details,created_at')
        .or('entity.eq.agroapteka_store,entity.eq.agroapteka_product,entity.eq.agroapteka_report')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  double? _numberOrNull(String value) => value.trim().isEmpty
      ? null
      : double.tryParse(value.trim().replaceAll(',', '.'));
  String _clean(String value) =>
      value.replaceAll(RegExp(r'[%(),*\\]'), ' ').trim();
}
