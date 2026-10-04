import 'package:uuid/uuid.dart';

class StockMovement {
  final String id;
  final String workspaceId;
  final String itemId;
  final String
  movementType; // 'purchase', 'consumption', 'adjustment', 'return', 'loss', 'transfer'
  final double quantity; // Positive for inflow, negative for outflow
  final int unitCostCents;
  final int totalCostCents;
  final String? projectId;
  final String? visitId;
  final String? purchaseId;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const StockMovement({
    required this.id,
    this.workspaceId = 'default',
    required this.itemId,
    required this.movementType,
    required this.quantity,
    this.unitCostCents = 0,
    this.totalCostCents = 0,
    this.projectId,
    this.visitId,
    this.purchaseId,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  /// Factory helper that enforces signed quantity based on movementType and calculates totalCostCents snapshot
  factory StockMovement.create({
    String? id,
    String workspaceId = 'default',
    required String itemId,
    required String movementType,
    required double quantity, // Absolute or signed amount
    int unitCostCents = 0,
    String? projectId,
    String? visitId,
    String? purchaseId,
    DateTime? date,
    String? notes,
  }) {
    if (projectId != null && visitId != null) {
      throw ArgumentError(
        'StockMovement cannot be associated with both Project and MaintenanceVisit simultaneously.',
      );
    }

    final double signedQty;
    final absQty = quantity.abs();

    switch (movementType.toLowerCase()) {
      case 'consumption':
      case 'loss':
        signedQty = -absQty;
        break;
      case 'purchase':
      case 'return':
        signedQty = absQty;
        break;
      case 'adjustment':
      case 'transfer':
      default:
        signedQty = quantity; // Preserves explicit sign for adjustments
        break;
    }

    final totalCents = (absQty * unitCostCents).round();
    final now = DateTime.now();

    return StockMovement(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      itemId: itemId,
      movementType: movementType.toLowerCase(),
      quantity: signedQty,
      unitCostCents: unitCostCents,
      totalCostCents: totalCents,
      projectId: projectId,
      visitId: visitId,
      purchaseId: purchaseId,
      date: date ?? now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
  }

  bool get isOutflow => quantity < 0;
  bool get isInflow => quantity > 0;
  double get quantityAbs => quantity.abs();
  double get unitCostSoles => unitCostCents / 100.0;
  double get totalCostSoles => totalCostCents / 100.0;

  String get typeLabel {
    switch (movementType) {
      case 'purchase':
        return 'Compra (+ Entrada)';
      case 'consumption':
        return 'Consumo (- Salida)';
      case 'adjustment':
        return quantity >= 0 ? 'Ajuste (+)' : 'Ajuste (-)';
      case 'return':
        return 'Devolución (+)';
      case 'loss':
        return 'Pérdida / Merma (-)';
      case 'transfer':
        return 'Transferencia';
      default:
        return movementType.toUpperCase();
    }
  }

  StockMovement copyWith({
    String? id,
    String? workspaceId,
    String? itemId,
    String? movementType,
    double? quantity,
    int? unitCostCents,
    int? totalCostCents,
    String? projectId,
    String? visitId,
    String? purchaseId,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      itemId: itemId ?? this.itemId,
      movementType: movementType ?? this.movementType,
      quantity: quantity ?? this.quantity,
      unitCostCents: unitCostCents ?? this.unitCostCents,
      totalCostCents: totalCostCents ?? this.totalCostCents,
      projectId: projectId ?? this.projectId,
      visitId: visitId ?? this.visitId,
      purchaseId: purchaseId ?? this.purchaseId,
      date: date ?? this.date,
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
      'itemId': itemId,
      'movementType': movementType,
      'quantity': quantity,
      'unitCostCents': unitCostCents,
      'totalCostCents': totalCostCents,
      'projectId': projectId,
      'visitId': visitId,
      'purchaseId': purchaseId,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String? ?? 'default',
      itemId: json['itemId'] as String,
      movementType: json['movementType'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitCostCents: json['unitCostCents'] as int? ?? 0,
      totalCostCents: json['totalCostCents'] as int? ?? 0,
      projectId: json['projectId'] as String?,
      visitId: json['visitId'] as String?,
      purchaseId: json['purchaseId'] as String?,
      date: DateTime.parse(json['date'] as String),
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
