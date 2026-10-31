import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage5_models.dart';
import '../market/market_repository.dart' show sanitizeSearch;

const _wcols =
    'id,name,region,storage_type,currency,owner_id,capacity_tons,free_tons,price_per_ton_month,address,conditions,contact_phone,image_url,accepted_products';

class WarehouseFilters {
  final String? region;
  final String? storageType;
  final String? acceptedProduct;
  final double? minCapacityTons;
  final double? minFreeTons;
  final double? maxPricePerTonMonth;

  const WarehouseFilters({
    this.region,
    this.storageType,
    this.acceptedProduct,
    this.minCapacityTons,
    this.minFreeTons,
    this.maxPricePerTonMonth,
  });

  bool get hasActive =>
      (region ?? '').trim().isNotEmpty || storageType != null ||
      (acceptedProduct ?? '').trim().isNotEmpty || minCapacityTons != null ||
      minFreeTons != null || maxPricePerTonMonth != null;
}

class WarehouseRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<Warehouse>> list(String query, [WarehouseFilters filters = const WarehouseFilters()]) async {
    var q = _c.from('warehouses').select(_wcols).eq('status', 'active');
    final t = sanitizeSearch(query);
    if (t.isNotEmpty) q = q.or('name.ilike.%$t%,region.ilike.%$t%');
    final region = sanitizeSearch(filters.region ?? '');
    if (region.isNotEmpty) q = q.ilike('region', '%$region%');
    if (filters.storageType != null) q = q.eq('storage_type', filters.storageType!);
    if (filters.minCapacityTons != null) q = q.gte('capacity_tons', filters.minCapacityTons!);
    if (filters.minFreeTons != null) q = q.gte('free_tons', filters.minFreeTons!);
    if (filters.maxPricePerTonMonth != null) q = q.lte('price_per_ton_month', filters.maxPricePerTonMonth!);
    final product = sanitizeSearch(filters.acceptedProduct ?? '');
    if (product.isNotEmpty) q = q.contains('accepted_products', [product]);
    final r = await q.order('created_at', ascending: false).limit(100);
    return (r as List)
        .map((e) => Warehouse.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Warehouse?> get(String id) async {
    final r =
        await _c.from('warehouses').select(_wcols).eq('id', id).maybeSingle();
    return r == null ? null : Warehouse.fromMap(r as Map<String, dynamic>);
  }

  Future<void> create({
    required String ownerId,
    required String name,
    required String region,
    required String storageType,
    required double capacityTons,
    required double freeTons,
    required String currency,
    required String imageUrl,
    double? pricePerTonMonth,
    String? address,
    String? conditions,
    String? contactPhone,
    List<String> acceptedProducts = const [],
  }) async {
    if (!capacityTons.isFinite ||
        capacityTons <= 0 ||
        !freeTons.isFinite ||
        freeTons < 0 ||
        freeTons > capacityTons ||
        (pricePerTonMonth != null &&
            (!pricePerTonMonth.isFinite || pricePerTonMonth < 0))) {
      throw ArgumentError('Invalid warehouse capacity or price');
    }
    await _c.from('warehouses').insert({
      'owner_id': ownerId,
      'name': name.trim(),
      'region': region,
      'storage_type': storageType,
      'capacity_tons': capacityTons,
      'free_tons': freeTons,
      'currency': currency,
      'image_url': imageUrl,
      'price_per_ton_month': pricePerTonMonth,
      'address': _nullable(address),
      'conditions': _nullable(conditions),
      'contact_phone': _nullable(contactPhone),
      'accepted_products': acceptedProducts,
      'status': 'active',
    });
  }

  String? _nullable(String? value) =>
      (value ?? '').trim().isEmpty ? null : value!.trim();

  Future<void> requestStorage(
      {required String warehouseId,
      required String farmerId,
      required String productType,
      required double tons,
      String? message}) async {
    await _c.from('storage_requests').insert({
      'warehouse_id': warehouseId,
      'farmer_id': farmerId,
      'product_type': productType.trim().toLowerCase(),
      'quantity_tons': tons,
      'message': (message ?? '').trim().isEmpty ? null : message!.trim(),
    });
  }
}
