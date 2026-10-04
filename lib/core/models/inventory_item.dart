import 'package:uuid/uuid.dart';

class InventoryItem {
  final String id;
  final String workspaceId;
  final String? sku;
  final String name;
  final String
  category; // 'plants', 'materials', 'supplies', 'fertilizers', 'pipes', etc.
  final String unit; // 'unit', 'm3', 'kg', 'm', 'bag', etc.
  final double minStockAlert;
  final int defaultCostCents;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const InventoryItem({
    required this.id,
    this.workspaceId = 'default',
    this.sku,
    required this.name,
    this.category = 'plants',
    this.unit = 'unit',
    this.minStockAlert = 0.0,
    this.defaultCostCents = 0,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  factory InventoryItem.create({
    String? id,
    String workspaceId = 'default',
    String? sku,
    required String name,
    String category = 'plants',
    String unit = 'unit',
    double minStockAlert = 0.0,
    int defaultCostCents = 0,
    bool isActive = true,
    String? notes,
  }) {
    final now = DateTime.now();
    return InventoryItem(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      sku: sku,
      name: name,
      category: category,
      unit: unit,
      minStockAlert: minStockAlert,
      defaultCostCents: defaultCostCents,
      isActive: isActive,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
  }

  double get defaultCostSoles => defaultCostCents / 100.0;

  String get categoryLabel {
    switch (category) {
      case 'plants':
        return 'Plantas';
      case 'materials':
        return 'Materiales';
      case 'supplies':
        return 'Insumos';
      case 'fertilizers':
        return 'Fertilizantes';
      case 'pipes':
        return 'Tuberías / Mangueras';
      default:
        return category.toUpperCase();
    }
  }

  String get unitLabel {
    switch (unit) {
      case 'unit':
        return 'Unidades';
      case 'm3':
        return 'm³';
      case 'kg':
        return 'kg';
      case 'm':
        return 'metros';
      case 'bag':
        return 'bolsas';
      case 'sack':
        return 'sacos';
      default:
        return unit;
    }
  }

  InventoryItem copyWith({
    String? id,
    String? workspaceId,
    String? sku,
    String? name,
    String? category,
    String? unit,
    double? minStockAlert,
    int? defaultCostCents,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      defaultCostCents: defaultCostCents ?? this.defaultCostCents,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'sku': sku,
      'name': name,
      'category': category,
      'unit': unit,
      'minStockAlert': minStockAlert,
      'defaultCostCents': defaultCostCents,
      'isActive': isActive,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String? ?? 'default',
      sku: json['sku'] as String?,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'plants',
      unit: json['unit'] as String? ?? 'unit',
      minStockAlert: (json['minStockAlert'] as num?)?.toDouble() ?? 0.0,
      defaultCostCents: json['defaultCostCents'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      version: json['version'] as int? ?? 1,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
