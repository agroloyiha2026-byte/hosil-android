import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/features/agroapteka/agroapteka_repository.dart';

void main() {
  test('public store data does not require or invent private profile fields', () {
    final store = AgroStore.fromMap({
      'id': 'store-id',
      'name': 'Agro store',
      'phone': '+998900000000',
      'region': 'Tashkent',
      'address': 'Business address',
      'status': 'approved',
      'is_verified': true,
      'location_public': false,
      'delivery_enabled': false,
    });

    expect(store.ownerId, isEmpty);
    expect(store.latitude, isNull);
    expect(store.longitude, isNull);
    expect(store.email, isNull);
    expect(store.productCount, 0);
  });

  test('optional product safety and package data remain absent when not supplied', () {
    final product = AgroProduct.fromMap({
      'id': 'product-id',
      'store_id': 'store-id',
      'title': 'Seed',
      'category': 'seeds',
      'currency': 'UZS',
      'unit': 'kg',
      'price': 0,
      'stock': 0,
    });

    expect(product.price, 0);
    expect(product.stock, 0);
    expect(product.manufacturer, isNull);
    expect(product.expiryDate, isNull);
    expect(product.safetyWarning, isNull);
    expect(product.published, isFalse);
  });
}
