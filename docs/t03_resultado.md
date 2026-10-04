# REPORTE DE RESULTADO: T-03 — LABOR PAYMENTS Y SALDOS DE TRABAJADORES

---

### Estado
`T-03 CLOSED`

---

### 1. Resumen Ejecutivo
Se implementó el ciclo completo de pagos a personal operativo (LaborPayments):
- Separación conceptual estricta: `WorkLog` = trabajo realizado (devengado) vs. `LaborPayment` = dinero entregado (pagado).
- Los WorkLogs nunca se marcan con `paid` ni mutan al registrar pagos.
- Los pagos a trabajadores (`LaborPayment`) **NO** aumentan ni alteran el costo laboral de las obras (el costo laboral se deriva exclusivamente de los WorkLogs).
- Cálculo dinámico de saldo de trabajador: `saldo = devengado - pagado`.
  - `saldo > 0`: Pendiente de pago al trabajador.
  - `saldo == 0`: Saldo liquidado.
  - `saldo < 0`: Adelanto a favor del trabajador.
- Soporte para pagos parciales, pagos completos, múltiples pagos acumulativos, adelantos, edición y anulación segura mediante soft delete (`deletedAt`).
- Métodos de pago normalizados: Efectivo (`cash`), Yape (`yape`), Plin (`plin`), Transferencia (`transfer`), Otro (`other`).
- Asociación opcional a Obra (`projectId` nullable).

---

### 2. Archivos Creados y Modificados
- `lib/core/models/labor_payment.dart`: Modelo de dominio `LaborPayment` con métodos de pago y extensiones.
- `lib/core/repositories/labor_payment_repository.dart`: Repositorio con cálculo reactivo de devengado, pagado y balance, validaciones y soft-delete.
- `lib/core/database/local_storage_service.dart`: Integración de `laborPaymentRepository`.
- `lib/features/payments/labor_payment_form_dialog.dart`: Diálogo de registro y edición con cálculo en vivo de saldo actual, monto ingresado y saldo posterior (con advertencia visual de adelanto).
- `lib/features/workers/worker_detail_screen.dart`: Visualización de tarjetas métricas (DEVENGADO, PAGADO, SALDO/ADELANTO) y sección de Pagos Realizados con menú de edición y anulación.
- `test/labor_payments_test.dart`: Suite completa de 12 pruebas unitarias e integrales contra SQLite real en memoria.

---

### 3. Casos de Prueba Verificados (12/12 en `test/labor_payments_test.dart`)
1. **Pago parcial**: Reduce el saldo pendiente en céntimos exactos.
2. **Pago completo**: Saldo queda exactamente liquidado (`balanceCents == 0`, `isSettled == true`).
3. **Múltiples pagos**: Acumulan correctamente el total pagado sobre múltiples jornadas.
4. **Adelanto**: Pago mayor al devengado produce saldo negativo (`hasAdvancePayment == true`).
5. **Anulación (Soft Delete)**: Pago anulado ya no resta del saldo y se preserva en auditoría.
6. **Modificación de pago**: Actualiza monto, método, notas y versionamiento optimista.
7. **Foreign Key Worker**: Inserción con `workerId` inexistente es rechazada a nivel de motor SQLite.
8. **Foreign Key Project**: Inserción con `projectId` inexistente es rechazada por SQLite.
9. **Validación `amountCents > 0`**: Montos menores o iguales a 0 son rechazados por validación y constraints.
10. **Invariante WorkLog**: Registrar un pago no muta ningún campo ni atributo del WorkLog original.
11. **Invariante Costo Laboral de Obra**: El pago (incluso asociado a una obra) no duplica ni altera el costo laboral de la obra.
12. **Cálculo de saldo exacto**: Precisión en céntimos con múltiples jornadas y pagos fraccionados.

---

### 4. Métricas de Calidad
- `flutter analyze`: **0 issues**.
- `flutter test`: **41 tests passed** (12 de T-03 + 14 de T-02 + 12 de migración + 3 de balance).
