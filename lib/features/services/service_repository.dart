import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../products/product_repository.dart' show hasRequiredListingImage;
import 'service_listing.dart';

const _serviceColumns =
    'id,owner_id,service_type,title,region,description,price_amount,currency,price_unit,contact_phone,status,image_url';

class ServiceRepository {
  SupabaseClient get _client {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<ServiceListing>> list(String type,
      {String? ownerId, bool pendingOnly = false}) async {
    if (type != 'equipment' && type != 'logistics')
      throw ArgumentError.value(type, 'type');
    var query = _client
        .from('service_listings')
        .select(_serviceColumns)
        .eq('service_type', type);
    if (ownerId != null) query = query.eq('owner_id', ownerId);
    if (pendingOnly) {
      query = query.eq('status', 'pending');
    } else if (ownerId == null) {
      query = query.eq('status', 'active');
    }
    final rows = await query.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((row) => ServiceListing.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceListing?> getPublic(String type, String id) async {
    if (type != 'equipment' && type != 'logistics')
      throw ArgumentError.value(type, 'type');
    final row = await _client
        .from('service_listings')
        .select(_serviceColumns)
        .eq('id', id)
        .eq('service_type', type)
        .eq('status', 'active')
        .maybeSingle();
    return row == null ? null : ServiceListing.fromMap(row);
  }

  Future<void> create({
    required String ownerId,
    required String type,
    required String title,
    required String region,
    required String description,
    required String currency,
    required String imageUrl,
    double? priceAmount,
    String? priceUnit,
    String? contactPhone,
  }) async {
    if (type != 'equipment' && type != 'logistics')
      throw ArgumentError.value(type, 'type');
    if (!hasRequiredListingImage(
        hasExistingImage: imageUrl.trim().isNotEmpty, selectedImageCount: 0)) {
      throw ArgumentError.value(
          imageUrl, 'imageUrl', 'A listing image is required');
    }
    await _client.from('service_listings').insert({
      'owner_id': ownerId,
      'service_type': type,
      'title': title.trim(),
      'region': region,
      'description': description.trim(),
      'currency': currency,
      'image_url': imageUrl,
      'price_amount': priceAmount,
      'price_unit': (priceUnit ?? '').trim().isEmpty ? null : priceUnit!.trim(),
      'contact_phone':
          (contactPhone ?? '').trim().isEmpty ? null : contactPhone!.trim(),
      'status': 'pending',
    });
  }

  Future<void> decide(String id, String status) async {
    if (status != 'active' && status != 'rejected')
      throw ArgumentError.value(status, 'status');
    final rows = await _client
        .from('service_listings')
        .update({'status': status})
        .eq('id', id)
        .eq('status', 'pending')
        .select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }

  Future<void> deleteOwn(String ownerId, String id) async {
    final rows = await _client
        .from('service_listings')
        .delete()
        .eq('id', id)
        .eq('owner_id', ownerId)
        .select('id');
    if ((rows as List).isEmpty) throw const AppError('error_permission');
  }
}
