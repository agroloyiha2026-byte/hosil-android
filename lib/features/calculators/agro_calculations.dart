class AgroCalculations {
  static double _positive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'Must be a finite positive number');
    }
    return value;
  }

  static double seedQuantityKg({required double rateKgPerHa, required double areaHa}) =>
      _positive(rateKgPerHa, 'rateKgPerHa') * _positive(areaHa, 'areaHa');

  static double fertilizerQuantityKg({required double rateKgPerHa, required double areaHa}) =>
      _positive(rateKgPerHa, 'rateKgPerHa') * _positive(areaHa, 'areaHa');

  static ({double nitrogenKg, double phosphorusKg, double potassiumKg}) npkContent({
    required double productKg,
    required double nitrogenPercent,
    required double phosphorusPercent,
    required double potassiumPercent,
  }) {
    _positive(productKg, 'productKg');
    for (final value in [nitrogenPercent, phosphorusPercent, potassiumPercent]) {
      if (!value.isFinite || value < 0 || value > 100) {
        throw ArgumentError.value(value, 'nutrientPercent', 'Must be between 0 and 100');
      }
    }
    return (
      nitrogenKg: productKg * nitrogenPercent / 100,
      phosphorusKg: productKg * phosphorusPercent / 100,
      potassiumKg: productKg * potassiumPercent / 100,
    );
  }

  static double irrigationVolumeM3({required double waterDepthMm, required double areaHa}) =>
      _positive(waterDepthMm, 'waterDepthMm') * _positive(areaHa, 'areaHa') * 10;

  static double expectedHarvestTons({required double yieldTonsPerHa, required double areaHa}) =>
      _positive(yieldTonsPerHa, 'yieldTonsPerHa') * _positive(areaHa, 'areaHa');

  static double totalCost({required double quantity, required double unitCost}) =>
      _positive(quantity, 'quantity') * _positive(unitCost, 'unitCost');
}
