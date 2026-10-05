import 'package:uuid/uuid.dart';

class Tool {
  final String id;
  final String workspaceId;
  final String? code;
  final String name;
  final String
  category; // 'manual', 'motorized', 'electric', 'safety', 'measurement', etc.
  final String? brandModel;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final int purchasePriceCents;
  final String
  currentStatus; // 'available', 'assigned', 'maintenance', 'retired'
  final String condition; // 'good', 'fair', 'damaged', 'in_repair'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const Tool({
    required this.id,
    this.workspaceId = 'default',
    this.code,
    required this.name,
    this.category = 'manual',
    this.brandModel,
    this.serialNumber,
    this.purchaseDate,
    this.purchasePriceCents = 0,
    this.currentStatus = 'available',
    this.condition = 'good',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  factory Tool.create({
    String? id,
    String workspaceId = 'default',
    String? code,
    required String name,
    String category = 'manual',
    String? brandModel,
    String? serialNumber,
    DateTime? purchaseDate,
    int purchasePriceCents = 0,
    String currentStatus = 'available',
    String condition = 'good',
    String? notes,
  }) {
    final now = DateTime.now();
    return Tool(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      code: code,
      name: name,
      category: category,
      brandModel: brandModel,
      serialNumber: serialNumber,
      purchaseDate: purchaseDate,
      purchasePriceCents: purchasePriceCents,
      currentStatus: currentStatus,
      condition: condition,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
  }

  bool get isAvailable => currentStatus == 'available';
  bool get isAssigned => currentStatus == 'assigned';
  bool get isInMaintenance => currentStatus == 'maintenance';
  bool get isRetired => currentStatus == 'retired';

  double get purchasePriceSoles => purchasePriceCents / 100.0;

  String get statusLabel {
    switch (currentStatus) {
      case 'available':
        return 'Disponible';
      case 'assigned':
        return 'Asignada / En Uso';
      case 'maintenance':
        return 'En Mantenimiento';
      case 'retired':
        return 'Retirada / Baja';
      default:
        return currentStatus.toUpperCase();
    }
  }

  String get conditionLabel {
    switch (condition) {
      case 'good':
        return 'Buen estado';
      case 'fair':
        return 'Regular';
      case 'damaged':
        return 'Dañada';
      case 'in_repair':
        return 'En reparación';
      default:
        return condition;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'motorized':
        return 'Motorizada';
      case 'electric':
        return 'Eléctrica / Batería';
      case 'manual':
        return 'Manual';
      case 'safety':
        return 'EPP / Seguridad';
      case 'measurement':
        return 'Medición';
      default:
        return category.toUpperCase();
    }
  }

  Tool copyWith({
    String? id,
    String? workspaceId,
    String? code,
    String? name,
    String? category,
    String? brandModel,
    String? serialNumber,
    DateTime? purchaseDate,
    int? purchasePriceCents,
    String? currentStatus,
    String? condition,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return Tool(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      brandModel: brandModel ?? this.brandModel,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
      currentStatus: currentStatus ?? this.currentStatus,
      condition: condition ?? this.condition,
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
      'code': code,
      'name': name,
      'category': category,
      'brandModel': brandModel,
      'serialNumber': serialNumber,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'purchasePriceCents': purchasePriceCents,
      'currentStatus': currentStatus,
      'condition': condition,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String? ?? 'default',
      code: json['code'] as String?,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'manual',
      brandModel: json['brandModel'] as String?,
      serialNumber: json['serialNumber'] as String?,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'] as String)
          : null,
      purchasePriceCents: json['purchasePriceCents'] as int? ?? 0,
      currentStatus: json['currentStatus'] as String? ?? 'available',
      condition: json['condition'] as String? ?? 'good',
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
