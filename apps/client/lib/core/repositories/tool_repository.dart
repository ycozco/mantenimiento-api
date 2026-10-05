import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/tool.dart' as model;
import '../models/tool_assignment.dart' as model;

class ToolRepository {
  final AppDatabase _db;

  ToolRepository(this._db);

  // ==================== TOOLS ====================

  Stream<List<model.Tool>> watchAllTools() {
    return (_db.select(_db.tools)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapToolRowToModel).toList());
  }

  Stream<List<model.Tool>> watchToolsByStatus(String status) {
    return (_db.select(_db.tools)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.currentStatus.equals(status),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapToolRowToModel).toList());
  }

  Future<model.Tool?> getTool(String id) async {
    final row =
        await (_db.select(_db.tools)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    return row != null ? _mapToolRowToModel(row) : null;
  }

  Future<void> createTool(model.Tool tool) async {
    await _db
        .into(_db.tools)
        .insert(
          ToolsCompanion(
            id: Value(tool.id),
            workspaceId: Value(tool.workspaceId),
            code: Value(tool.code),
            name: Value(tool.name),
            category: Value(tool.category),
            brandModel: Value(tool.brandModel),
            serialNumber: Value(tool.serialNumber),
            purchaseDate: Value(tool.purchaseDate),
            purchasePriceCents: Value(tool.purchasePriceCents),
            currentStatus: Value(tool.currentStatus),
            condition: Value(tool.condition),
            notes: Value(tool.notes),
            createdAt: Value(tool.createdAt),
            updatedAt: Value(tool.updatedAt),
            version: Value(tool.version),
          ),
        );
  }

  Future<void> updateTool(model.Tool tool) async {
    final now = DateTime.now();
    await (_db.update(_db.tools)..where((tbl) => tbl.id.equals(tool.id))).write(
      ToolsCompanion(
        code: Value(tool.code),
        name: Value(tool.name),
        category: Value(tool.category),
        brandModel: Value(tool.brandModel),
        serialNumber: Value(tool.serialNumber),
        purchaseDate: Value(tool.purchaseDate),
        purchasePriceCents: Value(tool.purchasePriceCents),
        currentStatus: Value(tool.currentStatus),
        condition: Value(tool.condition),
        notes: Value(tool.notes),
        updatedAt: Value(now),
        version: Value(tool.version + 1),
      ),
    );
  }

  Future<void> deleteTool(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.tools)..where((tbl) => tbl.id.equals(id))).write(
      ToolsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== ASSIGNMENT & LIFECYCLE ====================

  /// Checks out / assigns a tool.
  /// Enforces:
  /// 1. Retired tools cannot be assigned.
  /// 2. Maintenance tools cannot be assigned.
  /// 3. Invariant: One active assignment per tool (no simultaneous checkouts).
  Future<void> assignTool(model.ToolAssignment assignment) async {
    return _db.transaction(() async {
      final toolRow =
          await (_db.select(_db.tools)..where(
                (tbl) =>
                    tbl.id.equals(assignment.toolId) & tbl.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      if (toolRow == null) {
        throw ArgumentError('Herramienta no encontrada.');
      }

      if (toolRow.currentStatus == 'retired') {
        throw StateError(
          'Operación rechazada: La herramienta se encuentra retirada/dada de baja.',
        );
      }

      if (toolRow.currentStatus == 'maintenance') {
        throw StateError(
          'Operación rechazada: La herramienta está en mantenimiento o taller.',
        );
      }

      if (toolRow.currentStatus == 'assigned') {
        throw StateError(
          'Operación rechazada: La herramienta ya se encuentra asignada actualmente.',
        );
      }

      // Check if there is already an active assignment in tool_assignments table
      final activeAssignment =
          await (_db.select(_db.toolAssignments)..where(
                (tbl) =>
                    tbl.toolId.equals(assignment.toolId) &
                    tbl.returnedAt.isNull() &
                    tbl.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      if (activeAssignment != null) {
        throw StateError(
          'Operación rechazada: Existe una asignación activa previa sin devolución.',
        );
      }

      final now = DateTime.now();

      // Insert assignment record
      await _db
          .into(_db.toolAssignments)
          .insert(
            ToolAssignmentsCompanion(
              id: Value(assignment.id),
              workspaceId: Value(assignment.workspaceId),
              toolId: Value(assignment.toolId),
              workerId: Value(assignment.workerId),
              projectId: Value(assignment.projectId),
              maintenanceVisitId: Value(assignment.maintenanceVisitId),
              assignedAt: Value(assignment.assignedAt),
              expectedReturnAt: Value(assignment.expectedReturnAt),
              conditionOut: Value(assignment.conditionOut),
              notes: Value(assignment.notes),
              createdAt: Value(assignment.createdAt),
              updatedAt: Value(now),
              version: Value(assignment.version),
            ),
          );

      // Update tool status to assigned
      await (_db.update(
        _db.tools,
      )..where((tbl) => tbl.id.equals(assignment.toolId))).write(
        ToolsCompanion(
          currentStatus: const Value('assigned'),
          updatedAt: Value(now),
          version: Value(toolRow.version + 1),
        ),
      );
    });
  }

  /// Returns an assigned tool.
  /// Updates assignment with returnedAt and sets tool status back to 'available' (or 'maintenance' if damaged).
  Future<void> returnTool({
    required String assignmentId,
    DateTime? returnedAt,
    String? conditionIn,
    String? notes,
    bool sendToMaintenance = false,
  }) async {
    return _db.transaction(() async {
      final assignmentRow =
          await (_db.select(_db.toolAssignments)..where(
                (tbl) => tbl.id.equals(assignmentId) & tbl.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      if (assignmentRow == null) {
        throw ArgumentError('Asignación no encontrada.');
      }

      if (assignmentRow.returnedAt != null) {
        throw StateError('La asignación ya fue devuelta previamente.');
      }

      final returnTime = returnedAt ?? DateTime.now();
      final finalCondition = conditionIn ?? assignmentRow.conditionOut;

      // Close assignment
      await (_db.update(
        _db.toolAssignments,
      )..where((tbl) => tbl.id.equals(assignmentId))).write(
        ToolAssignmentsCompanion(
          returnedAt: Value(returnTime),
          conditionIn: Value(finalCondition),
          notes: notes != null ? Value(notes) : const Value.absent(),
          updatedAt: Value(returnTime),
          version: Value(assignmentRow.version + 1),
        ),
      );

      final nextStatus = sendToMaintenance || finalCondition == 'damaged'
          ? 'maintenance'
          : 'available';

      final toolRow = await (_db.select(
        _db.tools,
      )..where((tbl) => tbl.id.equals(assignmentRow.toolId))).getSingle();

      // Update tool status and condition
      await (_db.update(
        _db.tools,
      )..where((tbl) => tbl.id.equals(assignmentRow.toolId))).write(
        ToolsCompanion(
          currentStatus: Value(nextStatus),
          condition: Value(finalCondition),
          updatedAt: Value(returnTime),
          version: Value(toolRow.version + 1),
        ),
      );
    });
  }

  Future<void> sendToMaintenance(String toolId, {String? notes}) async {
    final tool = await getTool(toolId);
    if (tool == null) throw ArgumentError('Herramienta no encontrada.');
    if (tool.isAssigned) {
      throw StateError(
        'No se puede enviar a mantenimiento una herramienta asignada. Debe registrarse primero su devolución.',
      );
    }

    final now = DateTime.now();
    await (_db.update(_db.tools)..where((tbl) => tbl.id.equals(toolId))).write(
      ToolsCompanion(
        currentStatus: const Value('maintenance'),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(now),
        version: Value(tool.version + 1),
      ),
    );
  }

  Future<void> markAvailable(String toolId) async {
    final tool = await getTool(toolId);
    if (tool == null) throw ArgumentError('Herramienta no encontrada.');
    final now = DateTime.now();
    await (_db.update(_db.tools)..where((tbl) => tbl.id.equals(toolId))).write(
      ToolsCompanion(
        currentStatus: const Value('available'),
        updatedAt: Value(now),
        version: Value(tool.version + 1),
      ),
    );
  }

  Future<void> retireTool(String toolId, {String? reason}) async {
    final tool = await getTool(toolId);
    if (tool == null) throw ArgumentError('Herramienta no encontrada.');
    if (tool.isAssigned) {
      throw StateError(
        'No se puede dar de baja una herramienta asignada. Debe registrarse primero su devolución.',
      );
    }

    final now = DateTime.now();
    await (_db.update(_db.tools)..where((tbl) => tbl.id.equals(toolId))).write(
      ToolsCompanion(
        currentStatus: const Value('retired'),
        notes: reason != null ? Value(reason) : const Value.absent(),
        updatedAt: Value(now),
        version: Value(tool.version + 1),
      ),
    );
  }

  // ==================== QUERIES & STREAMS ====================

  Stream<List<model.ToolAssignment>> watchToolHistory(String toolId) {
    return (_db.select(_db.toolAssignments)
          ..where((tbl) => tbl.toolId.equals(toolId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.assignedAt)]))
        .watch()
        .map((rows) => rows.map(_mapAssignmentRowToModel).toList());
  }

  Future<model.ToolAssignment?> getActiveAssignment(String toolId) async {
    final row =
        await (_db.select(_db.toolAssignments)..where(
              (tbl) =>
                  tbl.toolId.equals(toolId) &
                  tbl.returnedAt.isNull() &
                  tbl.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row != null ? _mapAssignmentRowToModel(row) : null;
  }

  Stream<List<model.ToolAssignment>> watchProjectActiveAssignments(
    String projectId,
  ) {
    return (_db.select(_db.toolAssignments)
          ..where(
            (tbl) =>
                tbl.projectId.equals(projectId) &
                tbl.returnedAt.isNull() &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.assignedAt)]))
        .watch()
        .map((rows) => rows.map(_mapAssignmentRowToModel).toList());
  }

  Stream<List<model.ToolAssignment>> watchVisitActiveAssignments(
    String visitId,
  ) {
    return (_db.select(_db.toolAssignments)
          ..where(
            (tbl) =>
                tbl.maintenanceVisitId.equals(visitId) &
                tbl.returnedAt.isNull() &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.assignedAt)]))
        .watch()
        .map((rows) => rows.map(_mapAssignmentRowToModel).toList());
  }

  // ==================== MAPPERS ====================

  model.Tool _mapToolRowToModel(Tool row) {
    return model.Tool(
      id: row.id,
      workspaceId: row.workspaceId,
      code: row.code,
      name: row.name,
      category: row.category,
      brandModel: row.brandModel,
      serialNumber: row.serialNumber,
      purchaseDate: row.purchaseDate,
      purchasePriceCents: row.purchasePriceCents,
      currentStatus: row.currentStatus,
      condition: row.condition,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }

  model.ToolAssignment _mapAssignmentRowToModel(ToolAssignment row) {
    return model.ToolAssignment(
      id: row.id,
      workspaceId: row.workspaceId,
      toolId: row.toolId,
      workerId: row.workerId,
      projectId: row.projectId,
      maintenanceVisitId: row.maintenanceVisitId,
      assignedAt: row.assignedAt,
      expectedReturnAt: row.expectedReturnAt,
      returnedAt: row.returnedAt,
      conditionOut: row.conditionOut,
      conditionIn: row.conditionIn,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }
}
