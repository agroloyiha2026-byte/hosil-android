import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session_controller.dart';
import 'service_listing.dart';
import 'service_repository.dart';

final serviceRepoProvider = Provider((ref) => ServiceRepository());
final serviceListingsProvider = FutureProvider.autoDispose.family<List<ServiceListing>, String>(
    (ref, type) => ref.read(serviceRepoProvider).list(type));
final myServiceListingsProvider = FutureProvider.autoDispose.family<List<ServiceListing>, String>((ref, type) {
  final userId = ref.watch(sessionProvider.select((state) => state.user?.id));
  return userId == null ? Future.value(const <ServiceListing>[]) : ref.read(serviceRepoProvider).list(type, ownerId: userId);
});
final pendingServicesProvider = FutureProvider.autoDispose.family<List<ServiceListing>, String>(
    (ref, type) => ref.read(serviceRepoProvider).list(type, pendingOnly: true));
final publicServiceListingProvider =
    FutureProvider.autoDispose.family<ServiceListing?, ({String type, String id})>(
  (ref, target) => ref.read(serviceRepoProvider).getPublic(target.type, target.id),
);
