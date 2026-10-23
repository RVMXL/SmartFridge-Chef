/// Модель продукта холодильника (таблица `products`, Шаг 1 ТЗ).
///
/// Чистый Dart без зависимости от Flutter — используется и в UI,
/// и в юнит-тестах на sqflite_common_ffi.
library;

/// Категория продукта: ключ хранится в БД, локализованное имя даёт UI.
/// [defaultShelfLifeDays] — типовой срок хранения для быстрого ввода (Шаг 3):
/// пользователь ставит дату «+7 дней» одним тапом и правит при желании.
enum ProductCategory {
  dairy('dairy', 7),
  meat('meat', 3),
  fish('fish', 2),
  vegetables('vegetables', 7),
  fruits('fruits', 7),
  bakery('bakery', 3),
  grains('grains', 365),
  frozen('frozen', 180),
  beverages('beverages', 180),
  sweets('sweets', 120),
  condiments('condiments', 365),
  other('other', 14);

  const ProductCategory(this.key, this.defaultShelfLifeDays);

  /// Стабильный ключ хранения (не менять — уже в базах пользователей).
  final String key;

  /// Типовой срок хранения в днях для быстрого ввода.
  final int defaultShelfLifeDays;

  static ProductCategory fromKey(String key) => values.firstWhere(
        (c) => c.key == key,
        orElse: () => ProductCategory.other,
      );
}

/// Жизненный цикл продукта в холодильнике.
enum ProductStatus {
  active('active'),
  consumed('consumed'),
  discarded('discarded');

  const ProductStatus(this.key);
  final String key;

  static ProductStatus fromKey(String key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => ProductStatus.active,
      );
}

/// Единица измерения количества.
enum ProductUnit {
  pcs('pcs'),
  gram('g'),
  kilogram('kg'),
  milliliter('ml'),
  liter('l'),
  pack('pack');

  const ProductUnit(this.key);
  final String key;

  static ProductUnit fromKey(String key) => values.firstWhere(
        (u) => u.key == key,
        orElse: () => ProductUnit.pcs,
      );
}

/// Продукт на полке холодильника.
class Product {
  const Product({
    this.id,
    required this.name,
    required this.category,
    this.barcode,
    this.quantity = 1.0,
    this.unit = ProductUnit.pcs,
    required this.expiryDate,
    required this.addedAt,
    this.kcalPer100,
    this.proteinPer100,
    this.fatPer100,
    this.carbsPer100,
    this.notes,
    this.status = ProductStatus.active,
  });

  final int? id;
  final String name;

  /// Категория для группировки и сезонности меню.
  final ProductCategory category;

  /// Штрих-код EAN-13/UPC/EAN-8 (null при ручном вводе).
  /// По нему ищем продукт в Open Food Facts (Шаг 3).
  final String? barcode;

  final double quantity;
  final ProductUnit unit;

  /// Дата истечения срока годности (только дата, без времени).
  final DateTime expiryDate;

  /// Момент добавления в холодильник (дата и время).
  final DateTime addedAt;

  /// Пищевая ценность на 100 г/мл (из Open Food Facts, опционально).
  /// Нужна планировщику меню для сверки с БЖУ профиля (Шаг 2).
  final double? kcalPer100;
  final double? proteinPer100;
  final double? fatPer100;
  final double? carbsPer100;

  final String? notes;
  final ProductStatus status;

  /// Имя пользователя сделал вводимым обязательно; пустые строки запрещаем
  /// на уровне DAO перед вставкой (trim + непусто).
  bool get isValid => name.trim().isNotEmpty;

  /// Копия с частичной заменой полей.
  Product copyWith({
    int? id,
    String? name,
    ProductCategory? category,
    String? barcode,
    bool clearBarcode = false,
    double? quantity,
    ProductUnit? unit,
    DateTime? expiryDate,
    DateTime? addedAt,
    double? kcalPer100,
    double? proteinPer100,
    double? fatPer100,
    double? carbsPer100,
    String? notes,
    ProductStatus? status,
    bool clearNotes = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      addedAt: addedAt ?? this.addedAt,
      kcalPer100: kcalPer100 ?? this.kcalPer100,
      proteinPer100: proteinPer100 ?? this.proteinPer100,
      fatPer100: fatPer100 ?? this.fatPer100,
      carbsPer100: carbsPer100 ?? this.carbsPer100,
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name.trim(),
        'category_key': category.key,
        'barcode': barcode,
        'quantity': quantity,
        'unit_key': unit.key,
        'expiry_date': formatDate(expiryDate),
        'added_at': addedAt.toIso8601String(),
        'kcal_per_100': kcalPer100,
        'protein_per_100': proteinPer100,
        'fat_per_100': fatPer100,
        'carbs_per_100': carbsPer100,
        'notes': notes,
        'status': status.key,
      };

  static Product fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        category: ProductCategory.fromKey(map['category_key'] as String),
        barcode: map['barcode'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: ProductUnit.fromKey(map['unit_key'] as String? ?? 'pcs'),
        expiryDate: parseDate(map['expiry_date'] as String),
        addedAt: DateTime.parse(map['added_at'] as String),
        kcalPer100: (map['kcal_per_100'] as num?)?.toDouble(),
        proteinPer100: (map['protein_per_100'] as num?)?.toDouble(),
        fatPer100: (map['fat_per_100'] as num?)?.toDouble(),
        carbsPer100: (map['carbs_per_100'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        status: ProductStatus.fromKey(map['status'] as String? ?? 'active'),
      );

  /// Дата в виде `yyyy-MM-dd` — лексикографический порядок строк
  /// совпадает с хронологическим, поэтому сравнение дат в SQL честное.
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Разбор даты `yyyy-MM-dd` (полночь локального дня).
  static DateTime parseDate(String s) {
    final parts = s.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  String toString() =>
      'Product($id, $name, ${category.key}, до $expiryDate, $status)';
}
