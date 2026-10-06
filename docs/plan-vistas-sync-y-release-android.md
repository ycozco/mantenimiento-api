# Plan de vistas de sincronización y verificación Android

Fecha: 2026-10-06. Alcance: aplicación Flutter de Decolumax y piloto de 2 a 10 socios con NATS + JetStream. Este documento define entregables y criterios de aceptación; no afirma que las pantallas o la sincronización estén implementadas.

## Estado comprobado

| Componente | Estado actual | Decisión para el piloto |
|---|---|---|
| Flutter / Dart instalados | Flutter 3.44.0 estable / Dart 3.12.0, según `C:\src\flutter\bin\cache\flutter.version.json` | Fijar esta pareja para el primer ciclo de vistas y pruebas; evaluar un salto de SDK en un cambio separado. |
| App | `version: 1.0.0+1` en `apps/client/pubspec.yaml` | Incrementar nombre y número de compilación en cada entrega instalada sobre otra. Evitar duplicar el valor manualmente en `APP_VERSION`. |
| Android | AGP 9.0.1, Kotlin Gradle Plugin 2.3.20, Gradle 9.1.0 y Java de shell 25.0.2. Gradle de Flutter invocó el JBR de Android Studio, cuya versión exacta no se midió. | Flutter 3.44 usa compatibilidad temporal con KGP en AGP 9; `android.builtInKotlin=false` ya está configurado. Migrar a Kotlin integrado solo junto con Flutter 3.47+ y plugins compatibles. |
| Paquetes directos | `dart_nats 1.4.0` fijado; `flutter pub outdated --no-transitive` encuentra 1.6.1 resoluble. `shared_preferences` 2.5.5 admite 2.5.6. `build_runner` 2.15.1 permanece resoluble frente a 2.16.1 disponible. | Evaluar `dart_nats` en rama/commit propio con pruebas TLS, JetStream y reconexión. Actualizar el parche de `shared_preferences` por separado. No modificar todo el lockfile por una vista. |
| Análisis | `flutter analyze --fatal-infos` sin incidencias en el árbol local revisado. | Mantener cero errores, warnings y avisos deprecados del código propio antes de compilar cada entrega. |
| Compilación debug | `flutter build apk --debug --no-pub` terminó correctamente sin warnings visibles de deprecación. Artefacto de 195.054.976 bytes en `apps/client/build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `638F2EEDED962ECA343841FBA37B6E94494A847725482122B3144143F3852A28`. | Usar como línea de base de compilación; aún faltan firma release, instalación y pruebas funcionales en móviles. |
| Pruebas | `flutter test --no-pub`: 194 pasan y 12 fallan, todas en `dashboard_operational_test.dart`. La consulta de `DashboardService` usa `current_status = "maintenance"` como identificador SQLite; la pantalla también sustituye errores por un resumen vacío. | Corregir consulta y estado de error antes de aprobar cualquier piloto o usar este resultado como gate de release. |
| Datos | `WorkerRepository` y `SyncQueueRepository` ya filtran por workspace; la outbox tiene estados `PENDING`, `SENDING`, `DELIVERED`. Solo mantenimiento encola operaciones de negocio. | Terminar el aislamiento del resto de repositorios y el inbox antes de activar recepción de datos reales. |
| UI | Inicio, Obras, Mantto., Finanzas, Más y Ajustes existen. No hay vistas de identidad, invitaciones, dispositivos, estado sync o conflictos. | Mantener cinco destinos principales; abrir sincronización desde Más y mostrar un indicador breve en Inicio. |
| Release | `android/app/build.gradle.kts` aún firma `release` con la clave debug; identificador y nombre visible son de trabajo. | Configurar firma de distribución, nombre y applicationId definitivos antes de entregar un APK de producción. |

El manifest principal ya declara `android.permission.INTERNET`. La revisión de despliegue del 2026-10-05 decía que faltaba; prevalece el estado actual del archivo.

## Diseño de pantallas y comportamiento

Las vistas comparten el tema Material 3, tarjetas y estados comunes, navegación por intents y los cinco destinos ya existentes. Un socio del padrón financiero y un miembro autorizado para sincronizar son entidades diferentes.

| Vista / acceso | Contenido y acciones | Condición de aceptación |
|---|---|---|
| **Inicio: indicador compacto** | Organización activa, último intercambio y conteo de pendientes. Tocar abre el centro de sincronización. | Diferencia «guardado en este dispositivo», «enviado al buzón» y «aplicado por otro dispositivo»; no muestra «sincronizado» solo por un ACK del broker. |
| **Más → Sincronización** | Resumen por estado: conexión TLS, credencial, outbox, inbox, último recibo por socio, errores y reintento. | Funciona sin red y ofrece una explicación concreta para autenticación rechazada, certificado inválido, cuota llena y reconexión. Los reintentos conservan los eventos locales. |
| **Organización** | Crear identidad local o unirse mediante invitación; mostrar nombre, ID/huella verificable, rol y organización activa. | No usa el socio contable como credencial. Cambiar de organización nunca mezcla listas, consultas, adjuntos ni operaciones pendientes. |
| **Invitaciones** | Administrador genera código aleatorio de un uso y vencimiento; invitado presenta código y clave pública; administrador revisa huella, rol y confirma. | Código caducado/usado/rechazado no concede acceso. La aprobación genera credenciales y claves limitadas al dispositivo y organización; no guarda la clave raíz NATS en el móvil. |
| **Miembros y dispositivos** | Lista de dispositivos autorizados, rol, huella, última conexión, alta pendiente y revocación con confirmación. | Un dispositivo revocado pierde acceso al broker y a nuevas claves; la UI señala que datos descargados previamente no se pueden borrar a distancia. |
| **Conflictos** | Registro afectado, dos versiones, origen y fecha informativa; acciones de resolver o conservar ambas según tipo. | No decide ganadores por reloj del teléfono. Una resolución crea una operación nueva y permite auditar la elección. |
| **Recuperación** | Estado de retención, respaldo/snapshot disponible y progreso reanudable. | Un dispositivo que vuelve después de siete días no aparenta estar al día por recibir solo los mensajes restantes. |

Componentes reutilizables: `SyncStatusBadge`, `SyncStateCard`, `MemberDeviceTile`, `InvitationCodePanel`, `ConflictComparison` y estados comunes de carga/error/vacío. Datos y acciones llegan por controladores/servicios de sync; las pantallas no llaman directamente a NATS ni guardan secretos en widgets o preferencias ordinarias. Diseño adaptable a 320 px, teléfono normal y tableta, con texto escalado, navegación atrás y etiquetas semánticas.

## Secuencia de desarrollo y commits

1. **Corregir base funcional.** Parametrizar o corregir el literal SQL del dashboard; mostrar error y reintento reales en su pantalla. Repetir la suite hasta cero fallos. Commit sugerido: `fix(client): restore dashboard query and error state`.
2. **Base de datos y contexto.** Completar filtros de workspace en todos los repositorios, agregados, `LocalStorageService`, adjuntos y backup; pruebas de dos organizaciones. Crear identidad local de organización y dispositivo con almacenamiento seguro de claves. Commit: `refactor(client): enforce workspace context across data access`.
3. **Contrato de sincronización.** Versionar sobre de operación, ID estable, origen, dependencias causales, cifrado y recibos. Añadir inbox duradero e idempotente; ACK a JetStream después del commit Drift. Completar outbox en catálogos y mantenimiento. Commit: `feat(sync): persist versioned inbox and operation journal`.
4. **Transporte y provisión.** Probar la versión elegida de `dart_nats` con TLS, validación de hostname, autenticación individual, publicación, pull, ACK, reconexión y límites de buffers. Definir alta/revocación NATS sin poner credenciales globales en la app. Dos clientes reciben un evento con uno desconectado y reinicio del broker. Commit: `feat(sync): connect encrypted mobile mailbox`.
5. **Organización e invitaciones.** Implementar solicitudes, aprobación administrativa, código de un uso, expiración y listado/revocación de dispositivos; luego sus vistas y pruebas de denegación cruzada. Commit: `feat(client): manage organization invitations and devices`.
6. **Estado y recepción.** Construir centro de sincronización e indicador de Inicio usando estados reales de outbox, inbox y transporte. Agregar recibos de aplicación por dispositivo y errores accionables. Commit: `feat(client): show sync connection and delivery states`.
7. **Conflictos y recuperación.** Implementar reglas por módulo, vista de resolución, snapshot cifrado y reanudación tras caducidad de JetStream. Commit: `feat(client): resolve sync conflicts and recover replicas`.
8. **Módulos restantes y cierre visual.** Integrar inventario, compras, herramientas y finanzas con transacciones dominio + outbox; verificar navegación, accesibilidad y estados de error. Commit: `feat(sync): replicate remaining business modules`.
9. **Release Android.** Fijar versiones, firma, package ID, pruebas en dos móviles y artefacto firmado con hash. Commit: `chore(android): verify and package signed sync pilot`.

Cada fase termina con una demo verificable. No activar el botón de «Unirse» con una credencial común de NATS ni mostrar una sincronización exitosa antes de tener el recibo del dispositivo destinatario.

## Puertas de verificación de versiones y deprecaciones

Ejecutar desde `apps/client`, guardar salida de cada entrega y revisar los cambios de `pubspec.lock`:

```powershell
flutter --version
flutter doctor -v
flutter pub outdated --no-transitive
flutter analyze --fatal-infos
flutter test
flutter build apk --debug --no-pub
```

Antes de cambiar SDK o paquete, revisar las guías oficiales de cambios incompatibles y el changelog del paquete, ejecutar `dart fix --dry-run`, aplicar solo los cambios revisados y volver a analizar. No silenciar `deprecated_member_use` globalmente ni usar `ignore` como solución permanente. Separar avisos del código propio de los emitidos por plugins o Gradle; para estos últimos, actualizar o sustituir el paquete responsable después de probar su compatibilidad. En Flutter 3.44 con AGP 9, conservar `android.builtInKotlin=false` hasta migrar el proyecto y plugins a Kotlin integrado conforme a la guía oficial.

Para cada release, actualizar `version` en `pubspec.yaml` y generar los metadatos de la pantalla de versión desde la misma fuente o comprobar automáticamente su igualdad. Un `versionCode` Android debe crecer respecto al APK anterior. Construir el APK de piloto firmado y separado por ABI si se distribuye directamente; registrar nombre, tamaño y SHA-256. Para Play Store, producir AAB. La documentación de Flutter explica ambos formatos y la firma.

Pruebas finales: `flutter test` completo, widgets de cada estado y tamaño de pantalla, integración en dos Android físicos, TLS válido e inválido, invitación de un uso, revocación, cierre de app, pérdida de red, Doze, recepción tras reinicio, cuota llena y recuperación tras expirar mensajes. Verificar que una publicación confirmada por NATS aún aparezca como pendiente de aplicación hasta recibir el recibo del socio. La prueba de integración de Flutter se ejecuta en dispositivo y permite comprobar la UI real.

## Referencias oficiales

- [Flutter: cambios incompatibles](https://docs.flutter.dev/release/breaking-changes) y [migración a Kotlin integrado](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).
- [Dart: análisis](https://dart.dev/tools/dart-analyze), [dart fix](https://dart.dev/tools/dart-fix) y [pub outdated](https://dart.dev/tools/pub/cmd/pub-outdated).
- [Flutter: compilación Android](https://docs.flutter.dev/deployment/android) y [pruebas de integración](https://docs.flutter.dev/testing/integration-tests).
