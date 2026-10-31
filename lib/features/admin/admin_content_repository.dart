import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';

const _tables = {'banners', 'ads', 'product_categories'};

/// Ochiq URL dan Storage yo'lini ajratadi (bucket: images). Topilmasa null.
String? storagePathFromUrl(String url) {
  const m = '/object/public/images/';
  final i = url.indexOf(m);
  return i < 0 ? null : Uri.decodeComponent(url.substring(i + m.length).split('?').first);
}

/// Hamma yozuvlar RLS bo'yicha faqat adminga ruxsat etilgan; o'zgarishlar audit triggeri orqali jurnalga tushadi.
class AdminContentRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  void _check(String t) {
    if (!_tables.contains(t)) throw ArgumentError('Ruxsat etilmagan jadval: $t');
  }

  Future<List<Map<String, dynamic>>> rows(String table) async {
    _check(table);
    final r = await _c.from(table).select().order(table == 'product_categories' ? 'sort_order' : 'created_at', ascending: table == 'product_categories');
    return (r as List).cast<Map<String, dynamic>>();
  }

  Future<void> insertRow(String table, Map<String, dynamic> data) async {
    _check(table);
    await _c.from(table).insert(data);
  }

  Future<bool> bannerTargetExists(String type, String value) async {
    if (value.trim().isEmpty) return false;
    switch (type) {
      case 'product':
        return await _c.from('products').select('id').eq('id', value)
                .eq('status', 'active').eq('moderation_status', 'approved').maybeSingle() !=
            null;
      case 'category':
        return await _c.from('product_categories').select('slug').eq('slug', value)
                .eq('active', true).maybeSingle() !=
            null;
      case 'agroapteka':
        return await _c.from('agroapteka_stores').select('id').eq('id', value)
                .eq('status', 'approved').eq('is_verified', true).maybeSingle() !=
            null;
      case 'warehouse':
        return await _c.from('warehouses').select('id').eq('id', value)
                .eq('status', 'active').maybeSingle() !=
            null;
      case 'equipment':
      case 'logistics':
        return await _c.from('service_listings').select('id').eq('id', value)
                .eq('service_type', type).eq('status', 'active').maybeSingle() !=
            null;
      default:
        return false;
    }
  }

  Future<Map<String, Map<String, String>>> bannerTargetOptions({String language = 'uz'}) async {
    final products = await _c.from('products').select('id,title,region')
        .eq('status', 'active').eq('moderation_status', 'approved').order('title').limit(100);
    final categories = await _c.from('product_categories').select('slug,name_uz,name_ru,name_en')
        .eq('active', true).order('sort_order').limit(100);
    final stores = await _c.from('agroapteka_stores').select('id,name,region')
        .eq('status', 'approved').eq('is_verified', true).order('name').limit(100);
    final warehouses = await _c.from('warehouses').select('id,name,region')
        .eq('status', 'active').order('name').limit(100);
    final equipment = await _c.from('service_listings').select('id,title,region')
        .eq('service_type', 'equipment').eq('status', 'active').order('title').limit(100);
    final logistics = await _c.from('service_listings').select('id,title,region')
        .eq('service_type', 'logistics').eq('status', 'active').order('title').limit(100);

    String label(Map<String, dynamic> row, String titleColumn) {
      final title = row[titleColumn] as String;
      final region = row['region'] as String?;
      return region == null || region.isEmpty ? title : '$title · $region';
    }

    Map<String, String> options(List<dynamic> rows, String idColumn, String titleColumn) => {
      for (final row in rows.cast<Map<String, dynamic>>())
        row[idColumn] as String: label(row, titleColumn),
    };
    final categoryNameColumn = switch (language) {
      'ru' => 'name_ru',
      'en' => 'name_en',
      _ => 'name_uz',
    };
    return {
      'product': options(products as List, 'id', 'title'),
      'category': options(categories as List, 'slug', categoryNameColumn),
      'agroapteka': options(stores as List, 'id', 'name'),
      'warehouse': options(warehouses as List, 'id', 'name'),
      'equipment': options(equipment as List, 'id', 'title'),
      'logistics': options(logistics as List, 'id', 'title'),
    };
  }

  Future<void> updateRow(String table, String idColumn, String id, Map<String, dynamic> data) async {
    _check(table);
    await _c.from(table).update(data).eq(idColumn, id);
  }

  Future<void> deleteRow(String table, String id, {String? imageUrl}) async {
    _check(table);
    await _c.from(table).delete().eq('id', id);
    final path = imageUrl == null ? null : storagePathFromUrl(imageUrl);
    if (path != null) {
      try { await _c.storage.from('images').remove([path]); } catch (_) {/* faqat o'z papkangizdagi fayl o'chadi; xato e'tiborga olinmaydi */}
    }
  }

  Future<Map<String, String>> settings() async {
    final r = await _c.from('site_settings').select('key,value');
    return {for (final e in r as List) e['key'] as String: (e['value'] as String?) ?? ''};
  }

  Future<void> saveSetting(String key, String value) async => _c.from('site_settings').upsert({'key': key, 'value': value});

  Future<List<Map<String, dynamic>>> reports() async {
    final r = await _c.from('reports').select('id,reason,resolved,product_id,created_at,products(title)').order('resolved').order('created_at', ascending: false).limit(100);
    return (r as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveReport(String id) async => _c.from('reports').update({'resolved': true}).eq('id', id);

  Future<List<Map<String, dynamic>>> audit() async {
    final r = await _c.from('audit_logs').select('id,actor_id,action,entity,entity_id,created_at').order('created_at', ascending: false).limit(100);
    return (r as List).cast<Map<String, dynamic>>();
  }
}
