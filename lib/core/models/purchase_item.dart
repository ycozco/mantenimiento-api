import 'package:uuid/uuid.dart';

class PurchaseItem {
  final String id;
  final String workspaceId;
  final String purchaseId;
  final String itemId;
  final double quantity;
  final int unitCostCents;
  final int totalCostCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  // Non-persisted join metadata for UI
  final String? itemName;
  final String? itemUnit;

  PurchaseItem({
    required this.id,
    this.workspaceId = 'default',
    required this.purchaseId,
    required this.itemId,
    required this.quantity,
    required this.unitCostCents,
    required this.totalCostCents,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
    this.itemName,
    this.itemUnit,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PurchaseItem.create({
    String? id,
    String workspaceId = 'default',
    required String purchaseId,
    required String itemId,
    required double quantity,
    required int unitCostCents,
    String? createdBy,
    String? itemName,
    String? itemUnit,
  }) {
    if (quantity <= 0) {
      throw ArgumentError('La cantidad comprada debe ser mayor a cero.');
    }
    if (unitCostCents < 0) {
      throw ArgumentError('El costo unitario no puede ser negativo.');
    }

    final calculatedTotal = (quantity * unitCostCents).round();
    final now = DateTime.now();

    return PurchaseItem(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      purchaseId: purchaseId,
      itemId: itemId,
      quantity: quantity,
      unitCostCents: unitCostCents,
      totalCostCents: calculatedTotal,
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      version: 1,
      itemName: itemName,
      itemUnit: itemUnit,
    );
  }

  double get unitCost => unitCostCents / 100.0;
  double get totalCost => totalCostCents / 100.0;
}
