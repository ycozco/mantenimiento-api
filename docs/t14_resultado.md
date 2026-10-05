# Resultado de Implementación: T-14 — Configuración Empresarial y del Dispositivo

## 1. Resumen Ejecutivo
Se implementó la separación estricta entre la **Configuración Empresarial / Workspace** (sincronizable, compartible y respaldable) y las **Preferencias del Dispositivo** (locales a cada terminal de usuario, no sincronizables). Se rediseñó la pantalla de Ajustes en cinco secciones funcionales coherentes.

- **Estado:** `T-14 CLOSED`
- **Tests totales acumulados:** 146 passing (10 tests específicos en `test/settings_test.dart`)
- **Análisis estático:** `flutter analyze`: 0 issues
- **Commit:** `feat(settings): implement T-14 company and device settings`

---

## 2. Arquitectura de Separación

### 2.1 Configuración de Empresa / Workspace (`CompanySettings`)
- **Persistencia:** Tabla `app_metadata` en SQLite/Drift bajo la clave canónica `'company_settings'`.
- **Naturaleza:** Pertenece al negocio y al workspace. Es respaldable y sincronizable en el futuro multiusuario.
- **Campos:**
  - `workspaceId`: `'default'` (técnico, desacoplado del nombre comercial)
  - `companyName`: `'Decolumax EIRL'`
  - `legalName`: Opcional (Razón social)
  - `ruc`: Opcional (11 dígitos)
  - `phone`, `email`, `address`: Datos de contacto comercial
  - `currency`: `'PEN'` (Soles)
  - `timezone`: `'America/Lima'`
  - `allowNegativeStock`: Booleano (Control operativo de stock)
  - `defaultWorkDayHours`: `8.0` horas
  - `defaultNotificationHour`: `9` (09:00 AM)
  - `updatedAt`: Timestamp de auditoría

### 2.2 Preferencias del Dispositivo (`DevicePreferences`)
- **Persistencia:** `SharedPreferences` del sistema operativo móvil/escritorio.
- **Naturaleza:** Específica del dispositivo y del usuario físico actual. NO se sincroniza ni se incluye en el archivo de backup empresarial de SQLite.
- **Campos:**
  - `themeMode`: `'dark'`, `'light'`, `'system'`
  - `notificationsEnabled`: Booleano
  - `compactView`: Booleano
  - `lastScreen`: Identificador de última ruta visitada

---

## 3. Repositorios y Servicios

1. `lib/core/models/company_settings.dart`: Modelo inmutable con validación, serialización JSON y fábrica de valores por defecto.
2. `lib/core/models/device_preferences.dart`: Modelo de configuración del dispositivo.
3. `lib/core/repositories/settings_repository.dart`: Repositorio Drift con métodos reactivos (`watchSettings`), transaccionales (`updateSettings`), `setAllowNegativeStock`, y fallback a defaults si la base está vacía.
4. `lib/core/services/device_preferences_service.dart`: Servicio para lectura y modificación en `SharedPreferences`.
5. `lib/core/database/local_storage_service.dart`: Expone `settingsRepository` y `devicePreferencesService`.

---

## 4. Reorganización de UI: `AjustesScreen`

La vista `AjustesScreen` (`lib/features/ajustes/ajustes_screen.dart`) se estructuró en 5 secciones:
1. **EMPRESA:** Datos de Decolumax EIRL, moneda PEN, zona horaria Lima, RUC y botón para editar en diálogo.
2. **OPERACIONES:** Switch para permitir/denegar stock negativo, duración estándar de jornada y accesos directos a los catálogos operativos (Inventario, Herramientas, Proveedores).
3. **NOTIFICACIONES:** Switch local para habilitar/deshabilitar alertas en el terminal y cuadro explicativo de las 4 reglas de anticipación (7, 3, 2, 1 días).
4. **BACKUP Y DATOS:** Acciones para exportar e importar respaldo JSON.
5. **SISTEMA:** Workspace ID técnico, versión de la app, estado de Drift Local-First y tema del dispositivo.

---

## 5. Pruebas Automatizadas

En `test/settings_test.dart` (10 tests passing):
1. **Defaults:** Valores iniciales canónicos cuando la base de datos está vacía.
2. **Company Name:** Identidad predeterminada Decolumax EIRL.
3. **Moneda oficial:** `PEN` asegurado.
4. **Zona horaria:** `America/Lima` asegurado.
5. **Cambio de setting:** Modificación y actualización de datos fiscales y de contacto.
6. **Persistencia:** Verificación en bajo nivel en la tabla `app_metadata`.
7. **allowNegativeStock:** Alternancia del interruptor de inventario negativo.
8. **Preferencia local:** Serialización y deserialización de `DevicePreferences`.
9. **Separación Empresa / Dispositivo:** Garantía de que cambios en `SharedPreferences` no contaminan ni escriben en tablas de negocio.
10. **Persistencia tras reinicio:** Una nueva instancia de `SettingsRepository` recupera exactamente los valores configurados.
