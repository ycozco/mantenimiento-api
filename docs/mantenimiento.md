# 🛠️ Documentación Integral de la Aplicación: Mantenimientos & Gastos Compartidos

Esta documentación detalla la arquitectura, el diseño visual, las dependencias y cada una de las funcionalidades implementadas en la aplicación Flutter, incluyendo sus rutas absolutas dentro del proyecto.

---

## 🏛️ 1. Arquitectura del Sistema

La aplicación fue desarrollada bajo un enfoque **100% Offline-First (Sin Login Obligatorio ni Servidores en la Nube)**, garantizando que los técnicos y socios puedan operar en zonas sin cobertura, conservando todos sus datos en el almacenamiento interno del dispositivo.

### Diagrama de Flujo y Módulos

```
[UI Views / Screens]
   │
   ├── [MantenimientosScreen] ──► [MantenimientoFormDialog]
   ├── [ObrasScreen]           ──► [ObraFormDialog]
   ├── [GastosScreen]          ──► [GastoFormDialog]
   ├── [SociosClientesScreen]
   └── [AjustesScreen]
         │ (ListenableBuilder / ChangeNotifier)
         ▼
[LocalStorageService] ◄──► [BalanceCalculator] (Algoritmo de Liquidación)
   │               │
   ▼               ▼
[Archivo JSON]   [NotificationService] (flutter_local_notifications + timezone)
(Persistencia)   (Alertas a 7, 3, 2 y 1 días)
```

---

## 📂 2. Estructura del Proyecto y Rutas Absolutas

Todos los archivos del proyecto se encuentran organizados de forma modular:

### ⚙️ Configuración y Punto de Entrada
- **Punto de Entrada**: [`lib/main.dart`](file:///e:/mantenimiento/lib/main.dart)  
  *Inicializa el binding de Flutter, la localización de fechas en español (`intl`), el motor de notificaciones locales, la carga de datos del archivo local y arranca la interfaz.*
- **Dependencias y Assets**: [`pubspec.yaml`](file:///e:/mantenimiento/pubspec.yaml)  
  *Contiene las dependencias modernas (`flutter_lucide`, `flutter_local_notifications`, `timezone`, `path_provider`, `share_plus`, `intl`, `uuid`, `shared_preferences`).*
- **Manifiesto de Android**: [`android/app/src/main/AndroidManifest.xml`](file:///e:/mantenimiento/android/app/src/main/AndroidManifest.xml)  
  *Configura permisos de notificaciones exactas (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`) y los receivers de reinicio del dispositivo.*
- **Configuración de Gradle Android**: [`android/app/build.gradle.kts`](file:///e:/mantenimiento/android/app/build.gradle.kts)  
  *Habilita `isCoreLibraryDesugaringEnabled = true` con `desugar_jdk_libs:2.1.4` para compatibilidad de Java 8 Time APIs en Android.*
- **Propiedades de Gradle**: [`android/gradle.properties`](file:///e:/mantenimiento/android/gradle.properties)  
  *Configura `kotlin.incremental=false` para garantizar compilaciones robustas entre unidades de almacenamiento en Windows.*

---

### 🎨 Núcleo y Estilos Visuales (Core Theme)
- **Tema Visual**: [`lib/core/theme/app_theme.dart`](file:///e:/mantenimiento/lib/core/theme/app_theme.dart)
  - **Paleta Industrial Precision**:
    - **Fondo Oscuro Primario**: `#0F172A` (Slate Dark)
    - **Superficie de Tarjetas**: `#1E293B` con bordes en `#334155`
    - **Acento Alertas & Mantenimientos**: `#F59E0B` (Amber Safety)
    - **Acento Finanzas & Saldos a Favor**: `#10B981` (Emerald Green)
    - **Acento Obras & Proyectos**: `#0EA5E9` (Sky Blue)
    - **Acento Urgente / Vencidos**: `#EF4444` (Coral Red)
  - **Iconografía**: Librería `flutter_lucide` con iconos lineales estilizados y consistentes.
  - **Diseño Responsivo**: Todas las tarjetas y diálogos implementan `Wrap`, `Expanded` y restricciones proporcionales de pantalla para evitar desbordamientos (*overflow*) en cualquier resolución de teléfono.

---

### 📦 Modelos de Datos (Entities)
- **Modelo de Mantenimiento**: [`lib/core/models/mantenimiento.dart`](file:///e:/mantenimiento/lib/core/models/mantenimiento.dart)  
  *Define periodicidades (`1 mes`, `1.5 meses`, `2 meses`, `personalizado`), cálculo de días restantes, estado de urgencia/vencimiento y función para proyectar el siguiente ciclo automáticamente.*
- **Modelo de Gasto / Inversión**: [`lib/core/models/gasto.dart`](file:///e:/mantenimiento/lib/core/models/gasto.dart)  
  *Define categorías (gasolina, mantenimiento de herramientas/vehículo, comida, materiales de obra, herramientas, viáticos), socio pagador, vinculación a obras y modo de reparto (equitativo o por porcentajes).*
- **Calculadora de Balances**: [`lib/core/models/balance_calculator.dart`](file:///e:/mantenimiento/lib/core/models/balance_calculator.dart)  
  *Calcula el total aportado por cada socio, la cuota correspondiente a cada uno y resuelve la matriz de deudas simplificadas ("¿Quién debe a quién y cuánto?").*
- **Modelo de Obra / Proyecto**: [`lib/core/models/obra.dart`](file:///e:/mantenimiento/lib/core/models/obra.dart)  
  *Control de proyectos independientes con presupuesto, fechas de inicio/fin, ubicación, cliente y socios asignados.*
- **Modelo de Socio**: [`lib/core/models/socio.dart`](file:///e:/mantenimiento/lib/core/models/socio.dart)  
  *Representa a las 2 o más personas con ID, nombre, teléfono y color hexadecimal distintivo para avatares.*
- **Modelo de Cliente**: [`lib/core/models/cliente.dart`](file:///e:/mantenimiento/lib/core/models/cliente.dart)  
  *Directorio de clientes con nombre, teléfono, dirección y notas.*

---

### 💾 Servicios y Persistencia
- **Servicio de Almacenamiento Local**: [`lib/core/database/local_storage_service.dart`](file:///e:/mantenimiento/lib/core/database/local_storage_service.dart)  
  *Maneja el CRUD completo con persistencia atómica en archivo local JSON en el almacenamiento del teléfono (`mantenimiento_data.json`) y respaldo en `SharedPreferences`. Incluye métodos para exportar el respaldo y restaurarlo.*
- **Servicio de Notificaciones Locales**: [`lib/core/notifications/notification_service.dart`](file:///e:/mantenimiento/lib/core/notifications/notification_service.dart)  
  *Inicializa `flutter_local_notifications` y programa automáticamente las 4 alertas anticipadas exactas para cada mantenimiento.*

---

### 📱 Pantallas y Vistas (Features)
- **Contenedor Principal de Navegación**: [`lib/features/home/home_screen.dart`](file:///e:/mantenimiento/lib/features/home/home_screen.dart)  
  *Barra de navegación inferior moderna con 5 pestañas reactivas vinculadas al estado local.*
- **Pantalla de Mantenimientos**: [`lib/features/mantenimientos/mantenimientos_screen.dart`](file:///e:/mantenimiento/lib/features/mantenimientos/mantenimientos_screen.dart)  
  *Visualización de mantenimientos con chips de estado (`Faltan 7 días`, `Faltan 2 días`, `¡HOY!`, `Vencido`), filtros por tiempo y botón de completar ciclo.*
- **Modal de Nuevo/Editar Mantenimiento**: [`lib/features/mantenimientos/mantenimiento_form_dialog.dart`](file:///e:/mantenimiento/lib/features/mantenimientos/mantenimiento_form_dialog.dart)  
  *Selector de cliente, selector táctil de periodicidad (1m, 1.5m, 2m, custom), fecha con DatePicker y selección múltiple de socios responsables.*
- **Pantalla de Obras**: [`lib/features/obras/obras_screen.dart`](file:///e:/mantenimiento/lib/features/obras/obras_screen.dart)  
  *Lista de proyectos independientes, presupuesto total vs inversión ejecutada acumulada y botón de registro directo de gastos de obra.*
- **Modal de Nueva/Editar Obra**: [`lib/features/obras/obra_form_dialog.dart`](file:///e:/mantenimiento/lib/features/obras/obra_form_dialog.dart)  
  *Formulario para dar de alta obras con presupuesto, ubicación y asignación de socios.*
- **Pantalla de Gastos & Balances**: [`lib/features/gastos/gastos_screen.dart`](file:///e:/mantenimiento/lib/features/gastos/gastos_screen.dart)  
  - *Pestaña 1*: Historial completo de gastos con filtros, montos y pagador.
  - *Pestaña 2*: Tarjeta de liquidación directa ("Socio X debe pagar $Y a Socio Z") y desglose de aportes de cada socio.
- **Modal de Registro de Gasto**: [`lib/features/gastos/gasto_form_dialog.dart`](file:///e:/mantenimiento/lib/features/gastos/gasto_form_dialog.dart)  
  *Selector de categorías de gasto (gasolina, comida, herramientas, insumos), selector de quién pagó y configuración de reparto (partes iguales o porcentajes).*
- **Pantalla de Socios y Directorio de Clientes**: [`lib/features/socios_clientes/socios_clientes_screen.dart`](file:///e:/mantenimiento/lib/features/socios_clientes/socios_clientes_screen.dart)  
  *Gestión de 2 o más socios de trabajo con paleta de colores para sus avatares y directorio de clientes locales.*
- **Pantalla de Ajustes y Respaldo**: [`lib/features/ajustes/ajustes_screen.dart`](file:///e:/mantenimiento/lib/features/ajustes/ajustes_screen.dart)  
  *Exportar respaldo JSON para compartir por WhatsApp con el socio, restaurar respaldo y probar notificaciones en el dispositivo.*

---

### 🧪 Pruebas Unitarias Automatizadas
- **Pruebas de Lógica de Negocio y Finanzas**: [`test/balance_calculator_test.dart`](file:///e:/mantenimiento/test/balance_calculator_test.dart)  
  *Valida con precisión matemática los cálculos de intervalos (30, 45, 60 y días custom), el reparto equitativo y la liquidación de saldos netos entre socios.*

---

## 🎯 3. Resumen de Funcionalidades Implementadas

| Requerimiento del Usuario | Estado | Solución Técnica Implementada |
| :--- | :---: | :--- |
| **Sin login y guardado local** | ✅ | Persistencia atómica en archivo local JSON (`LocalStorageService`) sin necesidad de cuenta ni internet. |
| **Registrar 2 o más personas** | ✅ | Módulo de socios dinámico con nombres, teléfonos y selector de color para avatares. |
| **Repartir gastos de inversión** | ✅ | Soporte para gasolina, comida, herramientas y materiales en reparto equitativo (50/50 o 1/N) o por partes/porcentajes. |
| **Balance "¿Quién debe a quién?"** | ✅ | Algoritmo en `BalanceCalculator` que muestra las deudas netas simplificadas para cuadrar cuentas. |
| **Obras independientes** | ✅ | Módulo dedicado de proyectos/obras con cálculo de inversión ejecutada vs presupuesto. |
| **Frecuencias de mantenimiento** | ✅ | Selectores rápidos de 1 mes (30d), 1.5 meses (45d), 2 meses (60d) y días personalizados. |
| **Alertas anticipadas (7, 3, 2, 1 días)**| ✅ | Programación local con `flutter_local_notifications` a las 09:00 AM para 1 semana antes, 3 días, 2 días y 1 día antes. |
| **Iconos modernos / diseño** | ✅ | `flutter_lucide` con paleta Slate & Amber, tarjetas con bordes redondeados y layouts responsivos sin overflow. |
| **Exportación de respaldo** | ✅ | Botón para exportar archivo de respaldo y enviarlo por WhatsApp para sincronizar con el otro socio. |
