import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'passport_repository.dart';
import 'harvest_passport.dart';

final passportRepositoryProvider = Provider((ref) => PassportRepository());
final harvestPassportsProvider = FutureProvider.autoDispose<List<HarvestPassport>>(
    (ref) => ref.read(passportRepositoryProvider).mine());
