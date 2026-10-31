import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/features/services/service_listing.dart';

void main() {
  test('service listing maps optional public image URL', () {
    final listing = ServiceListing.fromMap({
      'id': 'listing-1',
      'owner_id': 'owner-1',
      'service_type': 'logistics',
      'title': 'Farm transport',
      'region': 'Tashkent',
      'description': 'Transport for agricultural produce.',
      'currency': 'UZS',
      'status': 'active',
      'image_url': 'https://storage.example/listing.webp',
    });

    expect(listing.imageUrl, 'https://storage.example/listing.webp');
  });

  test('older service rows remain readable without an image URL', () {
    final listing = ServiceListing.fromMap({
      'id': 'listing-2',
      'owner_id': 'owner-1',
      'service_type': 'equipment',
      'title': 'Tractor',
      'region': 'Samarqand',
      'description': 'Available for seasonal rental.',
      'currency': 'UZS',
      'status': 'active',
    });

    expect(listing.imageUrl, isNull);
  });
}
