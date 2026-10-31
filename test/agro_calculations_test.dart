import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/features/calculators/agro_calculations.dart';

void main() {
  test('seed rate is scaled by planted area', () {
    expect(AgroCalculations.seedQuantityKg(rateKgPerHa: 18, areaHa: 2.5), 45);
  });

  test('fertilizer requirement is scaled by area', () {
    expect(AgroCalculations.fertilizerQuantityKg(rateKgPerHa: 120, areaHa: 0.5), 60);
  });

  test('NPK content converts each declared percentage to mass', () {
    final result = AgroCalculations.npkContent(
      productKg: 100,
      nitrogenPercent: 15,
      phosphorusPercent: 10,
      potassiumPercent: 5,
    );
    expect(result.nitrogenKg, 15);
    expect(result.phosphorusKg, 10);
    expect(result.potassiumKg, 5);
  });

  test('irrigation volume uses 10 cubic metres per mm-hectare', () {
    expect(AgroCalculations.irrigationVolumeM3(waterDepthMm: 25, areaHa: 2), 500);
  });

  test('harvest and cost estimates use explicit multiplication', () {
    expect(AgroCalculations.expectedHarvestTons(yieldTonsPerHa: 4.2, areaHa: 3), closeTo(12.6, 0.0001));
    expect(AgroCalculations.totalCost(quantity: 12, unitCost: 2500), 30000);
  });

  test('invalid inputs are rejected', () {
    expect(() => AgroCalculations.seedQuantityKg(rateKgPerHa: 0, areaHa: 1), throwsArgumentError);
    expect(
      () => AgroCalculations.npkContent(
        productKg: 10,
        nitrogenPercent: 101,
        phosphorusPercent: 0,
        potassiumPercent: 0,
      ),
      throwsArgumentError,
    );
  });
}
