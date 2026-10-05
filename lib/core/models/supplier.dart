import 'package:uuid/uuid.dart';

class Supplier {
  final String id;
  final String workspaceId;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? taxId;
  final String? address;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  Supplier({
    required this.id,
    this.workspaceId = 'default',
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.taxId,
    this.address,
    this.isActive = true,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Supplier.create({
    String? id,
    String workspaceId = 'default',
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? taxId,
    String? address,
    bool isActive = true,
    String? notes,
    String? createdBy,
  }) {
    final now = DateTime.now();
    return Supplier(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      name: name.trim(),
      contactName: contactName?.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
      taxId: taxId?.trim(),
      address: address?.trim(),
      isActive: isActive,
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      version: 1,
    );
  }

  Supplier copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? taxId,
    String? address,
    bool? isActive,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return Supplier(
      id: id,
      workspaceId: workspaceId,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxId: taxId ?? this.taxId,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? (this.version + 1),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
