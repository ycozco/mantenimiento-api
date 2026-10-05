# T-17 Resultado: UX, Navegación y Responsive Mobile-Web

**Fecha:** 2026-10-04  
**Hito:** T-17 — UX / Navegación / Responsive Mobile-Web  
**Estado:** CLOSED  

---

## 1. Resumen Ejecutivo

El hito **T-17** unifica y organiza todos los módulos operacionales y financieros desarrollados desde T-01 hasta T-16 en una experiencia fluida, adaptable y ergonómica para dispositivos móviles (desde 320 px de ancho) y pantallas amplias (Web y Desktop hasta 1920 px).

Se implementó una abstracción de layout reactivo (`AppResponsive`, `ConstrainedContent`, `ResponsiveLayout`) con breakpoints estandarizados, se reestructuró la navegación principal a 5 destinos canónicos (`Inicio`, `Obras`, `Mantenimiento`, `Finanzas`, `Más`), se creó un **Centro Financiero** unificado (`FinanzasHubScreen`) con 5 pestañas de control y se organizaron los módulos secundarios en un menú categorizado (`MasMenuScreen`).

---

## 2. Arquitectura de Navegación y Responsive

### 2.1 Breakpoints Centralizados (`lib/core/theme/app_responsive.dart`)
- **Compact (`< 600 px`)**: Teléfonos móviles. Navegación inferior mediante `NavigationBar` (5 destinos) adaptada para touch con una sola mano.
- **Medium (`600 px - 1023 px`)**: Tablets y laptops compactas. Navegación lateral persistente con `NavigationRail`.
- **Expanded (`>= 1024 px`)**: Monitores de escritorio y Web. `NavigationRail` con branding Decolumax y contenido envuelto en `ConstrainedContent(maxContentWidth: 1200)` para evitar distorsión visual en pantallas de alta resolución.

### 2.2 Cinco Destinos Canónicos en `HomeScreen`
1. **Inicio (`DashboardScreen`)**: Tablero operacional con alertas prioritarias, agenda del día y métricas clave. Envuelto en `ConstrainedContent` y con rows protegidas contra overflow.
2. **Obras (`ObrasScreen`)**: Catálogo de proyectos, avance, cronograma y estados.
3. **Mantenimiento (`MantenimientosScreen`)**: Planes preventivos, visitas programadas y filtros de estado.
4. **Finanzas (`FinanzasHubScreen`)**: Centro financiero unificado con 5 pestañas:
   - *Rentabilidad*: Márgenes en vivo, presupuestos contratados y costos acumulados por obra.
   - *Cobros a Clientes*: Historial de cobros, métodos de pago, referencias y registro de cobros.
   - *Pagos a Trabajadores*: Historial de pagos de cuadrilla, métodos, liquidación y anulación controlada.
   - *Compras de Insumos*: Compras a proveedores vinculadas al kardex de inventario.
   - *Gastos y Socios*: Gastos operativos directos y balance de aportes/deudas entre socios.
5. **Más (`MasMenuScreen`)**: Menú agrupado en tarjetas responsivas:
   - *Operaciones y Recursos*: Inventario (Kardex), Herramientas, Personal (Trabajadores), Calendario Operacional.
   - *Directorio y Contactos*: Clientes, Proveedores, Socios.
   - *Sistema y Configuración*: Ajustes del Sistema (Empresa, Backup, Notificaciones).

### 2.3 Componentes de Estado Reutilizables (`lib/core/widgets/state_views.dart`)
- `EmptyStateView`: Icono destacado, título, descripción y botón de acción opcional.
- `ErrorStateView`: Mensaje de error formateado y acción de reintento.
- `LoadingStateView`: Indicador de progreso circular con etiqueta de contexto.

---

## 3. Auditoría de Responsividad en Pantallas Móviles

Se auditó rigurosamente la interfaz en dimensiones compactas:
- **320 px (Pantallas ultra-estrechas)**: Se corrigieron overflows en títulos de encabezados de sección y tarjetas financieras mediante `Expanded` con `TextOverflow.ellipsis`.
- **360 px (Android estándar)**: Navegación de 5 destinos perfectamente proporcionada sin etiquetas superpuestas.
- **390 px y 430 px (iPhones y terminales grandes)**: Espaciado uniforme y lectura ergonómica.

---

## 4. Archivos Modificados y Creados

| Tipo | Archivo | Descripción |
| :--- | :--- | :--- |
| **Creado** | `lib/core/theme/app_responsive.dart` | Breakpoints, helper reactivo y wrapper `ConstrainedContent`. |
| **Creado** | `lib/core/widgets/state_views.dart` | Vistas canónicas de carga, vacío y error. |
| **Creado** | `lib/features/finanzas/finanzas_hub_screen.dart` | Centro financiero con 5 pestañas de control unificado. |
| **Creado** | `lib/features/mas/mas_menu_screen.dart` | Menú organizado de módulos secundarios en tarjetas. |
| **Creado** | `test/navigation_responsive_test.dart` | 12 tests de widgets verificando breakpoints, navegación y ausencia de overflow. |
| **Modificado** | `lib/features/home/home_screen.dart` | Soporte dual: `NavigationBar` en móvil y `NavigationRail` en desktop/web. |
| **Modificado** | `lib/features/dashboard/dashboard_screen.dart` | Layout `ConstrainedContent`, rows seguras y ruteo a nuevas pestañas. |
| **Modificado** | `lib/features/socios_clientes/socios_clientes_screen.dart` | Parámetro `initialTab` para apertura directa de Socios (0), Trabajadores (1) o Clientes (2). |
| **Modificado** | `lib/core/repositories/collection_repository.dart` | `watchAllCollections()` reactivo. |
| **Modificado** | `lib/core/repositories/labor_payment_repository.dart` | `watchAllPayments()` reactivo. |

---

## 5. Resultados de Validación

- **`flutter analyze`**: 0 issues.
- **`flutter test`**: 182 tests passing (170 previos + 12 de T-17), 0 failed.
- **`dart format .`**: 100% formateado según convenciones.
- **Working Tree**: Limpio tras commit.
