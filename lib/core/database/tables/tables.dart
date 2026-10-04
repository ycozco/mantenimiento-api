import 'package:drift/drift.dart';

// --- USERS ---
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().withDefault(const Constant('default'))();
  TextColumn get email => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('owner'))();
  IntColumn get avatarColor =>
      integer().withDefault(const Constant(0xFFF59E0B))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- PARTNERS (SOCIOS) ---
class Partners extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable().customConstraint(
    'REFERENCES users(id) ON DELETE SET NULL',
  )();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  RealColumn get equityPercentage => real().withDefault(const Constant(50.0))();
  IntColumn get avatarColor =>
      integer().withDefault(const Constant(0xFFF59E0B))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- WORKERS (TRABAJADORES DE CAMPO - SIN LOGIN) ---
class Workers extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().withDefault(const Constant('default'))();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get specialty => text().nullable()();
  TextColumn get defaultPaymentType =>
      text().withDefault(const Constant('daily'))();
  IntColumn get defaultRateCents => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CLIENTS ---
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get taxId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CLIENT LOCATIONS (SEDES/DIRECCIONES DEL CLIENTE) ---
class ClientLocations extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text().customConstraint(
    'NOT NULL REFERENCES clients(id) ON DELETE CASCADE',
  )();
  TextColumn get name => text().withDefault(const Constant('Principal'))();
  TextColumn get address => text()();
  TextColumn get district => text().nullable()();
  TextColumn get reference => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- PROJECTS (OBRAS) ---
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get clientId => text().nullable().customConstraint(
    'REFERENCES clients(id) ON DELETE SET NULL',
  )();
  TextColumn get locationId => text().nullable().customConstraint(
    'REFERENCES client_locations(id) ON DELETE SET NULL',
  )();
  TextColumn get description => text().nullable()();
  IntColumn get budgetAmountCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get targetEndDate => dateTime().nullable()();
  DateTimeColumn get actualEndDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  TextColumn get assignedPartnerIdsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- MAINTENANCE PLANS (PLANES RECURRENTES) ---
class MaintenancePlans extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get clientId => text().customConstraint(
    'NOT NULL REFERENCES clients(id) ON DELETE CASCADE',
  )();
  TextColumn get locationId => text().nullable().customConstraint(
    'REFERENCES client_locations(id) ON DELETE SET NULL',
  )();
  TextColumn get description => text().nullable()();
  TextColumn get frequencyType => text().withDefault(const Constant('unMes'))();
  IntColumn get intervalDays => integer().withDefault(const Constant(30))();
  IntColumn get estimatedCostCents =>
      integer().withDefault(const Constant(0))();
  TextColumn get assignedPartnerIdsJson =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- MAINTENANCE VISITS (HISTORIAL DE VISITAS) ---
class MaintenanceVisits extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().customConstraint(
    'NOT NULL REFERENCES maintenance_plans(id) ON DELETE CASCADE',
  )();
  DateTimeColumn get scheduledDate => dateTime()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  TextColumn get technicianNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- INVENTORY ITEMS (CONSUMIBLES) ---
class InventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('plants'))();
  TextColumn get unit => text().withDefault(const Constant('unit'))();
  RealColumn get minStockAlert => real().withDefault(const Constant(0.0))();
  IntColumn get defaultCostCents => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- SUPPLIERS (PROVEEDORES) ---
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get taxId => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- PURCHASES (COMPRAS DE INSUMOS) ---
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text().nullable().customConstraint(
    'REFERENCES suppliers(id) ON DELETE SET NULL',
  )();
  TextColumn get paidByPartnerId =>
      text().customConstraint('NOT NULL REFERENCES partners(id)')();
  IntColumn get totalAmountCents => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get invoiceNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- STOCK MOVEMENTS (LEDGER DE INVENTARIO) ---
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().customConstraint(
    'NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE',
  )();
  TextColumn get movementType =>
      text().withDefault(const Constant('consumption'))();
  RealColumn get quantity => real()();
  IntColumn get unitCostCents => integer().withDefault(const Constant(0))();
  TextColumn get projectId => text().nullable().customConstraint(
    'REFERENCES projects(id) ON DELETE SET NULL',
  )();
  TextColumn get visitId => text().nullable().customConstraint(
    'REFERENCES maintenance_visits(id) ON DELETE SET NULL',
  )();
  TextColumn get purchaseId => text().nullable().customConstraint(
    'REFERENCES purchases(id) ON DELETE SET NULL',
  )();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TOOLS (HERRAMIENTAS / ACTIVOS) ---
class Tools extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get brandModel => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  IntColumn get purchasePriceCents =>
      integer().withDefault(const Constant(0))();
  TextColumn get currentStatus =>
      text().withDefault(const Constant('available'))();
  TextColumn get condition => text().withDefault(const Constant('good'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TOOL ASSIGNMENTS (HISTORIAL DE CUSTODIA) ---
class ToolAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get toolId => text().customConstraint(
    'NOT NULL REFERENCES tools(id) ON DELETE CASCADE',
  )();
  TextColumn get workerId => text().nullable().customConstraint(
    'REFERENCES workers(id) ON DELETE SET NULL',
  )();
  TextColumn get projectId => text().nullable().customConstraint(
    'REFERENCES projects(id) ON DELETE SET NULL',
  )();
  DateTimeColumn get assignedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get returnedAt => dateTime().nullable()();
  TextColumn get conditionOut => text().withDefault(const Constant('good'))();
  TextColumn get conditionIn => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- WORK LOGS (JORNADAS LABORALES) ---
class WorkLogs extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().withDefault(const Constant('default'))();
  TextColumn get workerId => text().customConstraint(
    'NOT NULL REFERENCES workers(id) ON DELETE RESTRICT',
  )();
  DateTimeColumn get date => dateTime()();
  TextColumn get projectId => text().nullable().customConstraint(
    'REFERENCES projects(id) ON DELETE CASCADE',
  )();
  TextColumn get maintenanceVisitId => text().nullable().customConstraint(
    'REFERENCES maintenance_visits(id) ON DELETE CASCADE',
  )();
  TextColumn get paymentType => text().withDefault(const Constant('daily'))();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  IntColumn get rateCents => integer().withDefault(const Constant(0))();
  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((project_id IS NOT NULL AND maintenance_visit_id IS NULL) OR (project_id IS NULL AND maintenance_visit_id IS NOT NULL))',
    'CHECK (quantity > 0 AND rate_cents >= 0 AND amount_cents >= 0)',
  ];
}

// --- LABOR PAYMENTS (PAGOS DE JORNALES A OBREROS) ---
class LaborPayments extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().withDefault(const Constant('default'))();
  TextColumn get workerId => text().customConstraint(
    'NOT NULL REFERENCES workers(id) ON DELETE RESTRICT',
  )();
  IntColumn get amountCents => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get paidByPartnerId =>
      text().customConstraint('NOT NULL REFERENCES partners(id)')();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- EXPENSES (GASTOS OPERATIVOS) ---
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get concept => text()();
  TextColumn get category => text().withDefault(const Constant('otro'))();
  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get paidByPartnerId =>
      text().customConstraint('NOT NULL REFERENCES partners(id)')();
  TextColumn get projectId => text().nullable().customConstraint(
    'REFERENCES projects(id) ON DELETE SET NULL',
  )();
  TextColumn get visitId => text().nullable().customConstraint(
    'REFERENCES maintenance_visits(id) ON DELETE SET NULL',
  )();
  TextColumn get splitMode =>
      text().withDefault(const Constant('equitativo'))();
  TextColumn get splitRatiosJson => text().withDefault(const Constant('{}'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CAPITAL MOVEMENTS (APORTES / RETIROS DE CAPITAL) ---
class CapitalMovements extends Table {
  TextColumn get id => text()();
  TextColumn get partnerId => text().customConstraint(
    'NOT NULL REFERENCES partners(id) ON DELETE CASCADE',
  )();
  TextColumn get type => text().withDefault(const Constant('investment'))();
  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- COLLECTIONS (COBROS A CLIENTES) ---
class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text().customConstraint(
    'NOT NULL REFERENCES clients(id) ON DELETE CASCADE',
  )();
  TextColumn get projectId => text().nullable().customConstraint(
    'REFERENCES projects(id) ON DELETE SET NULL',
  )();
  TextColumn get visitId => text().nullable().customConstraint(
    'REFERENCES maintenance_visits(id) ON DELETE SET NULL',
  )();
  IntColumn get amountCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get receivedByPartnerId =>
      text().customConstraint('NOT NULL REFERENCES partners(id)')();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- ATTACHMENTS (EVIDENCIAS FOTOGRÁFICAS Y COMPROBANTES) ---
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get parentType => text()();
  TextColumn get parentId => text()();
  TextColumn get stage => text().nullable()();
  TextColumn get localFilePath => text()();
  TextColumn get fileName => text()();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get mimeType => text().withDefault(const Constant('image/jpeg'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- SYNC QUEUE (COLA OUTBOX) ---
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

// --- APP METADATA (METADATOS Y CONTROL DE MIGRACIONES) ---
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
