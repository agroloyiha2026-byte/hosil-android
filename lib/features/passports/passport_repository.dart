import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import 'harvest_passport.dart';

class PassportRepository {
  get _client {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<HarvestPassport>> mine() async {
    final result = await _client.rpc('my_harvest_passports');
    final rows = result is List
        ? result
        : (result is Map && result['data'] is List)
            ? result['data'] as List
            : const <dynamic>[];
    return rows
        .map((item) => HarvestPassport.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> create(String productId) async {
    final result = await _client.rpc('create_harvest_passport', params: {'p_product_id': productId});
    if (result is! String || result.isEmpty) throw const AppError('error_generic');
    return result;
  }

  Future<void> revoke(String passportId) async {
    await _client.rpc('revoke_harvest_passport', params: {'p_passport_id': passportId});
  }
}
