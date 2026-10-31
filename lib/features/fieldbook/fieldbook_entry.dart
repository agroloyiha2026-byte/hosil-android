class FieldbookEntry {
  final String id;
  final String cropType;
  final String activityType;
  final DateTime entryDate;
  final double? quantity;
  final String? unit;
  final double? amount;
  final String currency;
  final String? note;
  final DateTime updatedAt;
  final bool deleted;
  final bool synced;

  const FieldbookEntry({
    required this.id,
    required this.cropType,
    required this.activityType,
    required this.entryDate,
    required this.updatedAt,
    this.quantity,
    this.unit,
    this.amount,
    this.currency = 'UZS',
    this.note,
    this.deleted = false,
    this.synced = false,
  });

  factory FieldbookEntry.fromLocalMap(Map<String, dynamic> map) => FieldbookEntry(
        id: map['id'] as String,
        cropType: map['crop_type'] as String,
        activityType: map['activity_type'] as String,
        entryDate: DateTime.parse(map['entry_date'] as String),
        quantity: (map['quantity'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        amount: (map['amount'] as num?)?.toDouble(),
        currency: (map['currency'] as String?) ?? 'UZS',
        note: map['note'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        deleted: (map['deleted'] as bool?) ?? false,
        synced: (map['synced'] as bool?) ?? false,
      );

  factory FieldbookEntry.fromRemoteMap(Map<String, dynamic> map) => FieldbookEntry(
        id: map['client_id'] as String,
        cropType: map['crop_type'] as String,
        activityType: map['activity_type'] as String,
        entryDate: DateTime.parse(map['entry_date'] as String),
        quantity: (map['quantity'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        amount: (map['amount'] as num?)?.toDouble(),
        currency: (map['currency'] as String?) ?? 'UZS',
        note: map['note'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        deleted: (map['deleted'] as bool?) ?? false,
        synced: true,
      );

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'crop_type': cropType,
        'activity_type': activityType,
        'entry_date': _dateOnly(entryDate),
        'quantity': quantity,
        'unit': unit,
        'amount': amount,
        'currency': currency,
        'note': note,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
        'synced': synced,
      };

  Map<String, dynamic> toRemoteMap() => {
        'crop_type': cropType,
        'activity_type': activityType,
        'entry_date': _dateOnly(entryDate),
        'quantity': quantity,
        'unit': unit,
        'amount': amount,
        'currency': currency,
        'note': note,
        'deleted': deleted,
      };

  FieldbookEntry copyWith({bool? deleted, bool? synced, DateTime? updatedAt}) => FieldbookEntry(
        id: id,
        cropType: cropType,
        activityType: activityType,
        entryDate: entryDate,
        quantity: quantity,
        unit: unit,
        amount: amount,
        currency: currency,
        note: note,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        synced: synced ?? this.synced,
      );

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
