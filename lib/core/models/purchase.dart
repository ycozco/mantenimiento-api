import 'package:uuid/uuid.dart';
import 'purchase_item.dart';

class Purchase {
  final String id;
  final String workspaceId;
  final String? supplierId;
  final String? paidByPartnerId;
  final int totalAmountCents;
  final DateTime date;
  final String documentType; // 'invoice', 'receipt', 'ticket', 'none', 'other'
  final String? invoiceNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  // Non-persisted join metadata for UI
  final String? supplierName;
  final String? partnerName;
  final List<PurchaseItem>? items;

  Purchase({
    required this.id,
    this.workspaceId = 'default',
    this.supplierId,
    this.paidByPartnerId,
    required this.totalAmountCents,
    required this.date,
    this.documentType = 'invoice',
    this.invoiceNumber,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
    this.supplierName,
    this.partnerName,
    this.items,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Purchase.create({
    String? id,
    String workspaceId = 'default',
    String? supplierId,
    String? paidByPartnerId,
    required int totalAmountCents,
    required DateTime date,
    String documentType = 'invoice',
    String? invoiceNumber,
    String? notes,
    String? createdBy,
  }) {
    if (totalAmountCents < 0) {
      throw ArgumentError('El monto total de compra no puede ser negativo.');
    }
    final now = DateTime.now();
    return Purchase(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      supplierId: supplierId,
      paidByPartnerId: paidByPartnerId,
      totalAmountCents: totalAmountCents,
      date: date,
      documentType: documentType,
      invoiceNumber: invoiceNumber?.trim(),
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      version: 1,
    );
  }

  bool get isDeleted => deletedAt != null;
  double get totalAmount => totalAmountCents / 100.0;
}
