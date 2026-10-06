# Revisión de implementación, VPS y app móvil

Fecha: 2026-10-05. Revisión del árbol de trabajo, incluidos cambios locales de interfaz aún no confirmados. No se accedió al VPS ni se verificó DNS, firewall o certificados reales. La revisión visual se limita al código y pruebas de widgets; no hubo inspección en teléfono físico ni capturas de todas las pantallas.

## Dictamen

La aplicación tiene una base funcional local amplia en Flutter/Drift, pero **no está lista para sincronización entre socios ni para publicación de producción**. NATS está evaluado mediante ensayos sintéticos, no integrado. El Compose disponible despliega NestJS + PostgreSQL y no corresponde al objetivo de un único buzón ultraligero.

Antes de ampliar arquitectura o estilos, corregir el dashboard, cerrar aislamiento por organización y elegir explícitamente NATS como transporte del piloto. Los módulos locales existentes deben conservarse y adaptar sus escrituras progresivamente; una reescritura completa no está justificada.

## Evidencia de validación actual

| Comprobación | Resultado |
|---|---|
| `flutter analyze` en apps/client | Sin incidencias |
| `flutter test` | 188 pasan, 12 fallan; fallos en dashboard_operational_test |
| Navegación adaptable dentro de esa suite | Pasa, incluidos menú a 320 px, navegación móvil y rail de tableta |
| `npm run build` en server/layer | Compila |
| `npm.cmd test -- --passWithNoTests=false` | No existen tests del servidor; salida 1 |
| Reproducción con ConfigService y jsonwebtoken instalados | TTL de entorno `"900"` produce duración 0 segundos; número `900` produce 900 segundos |
| Artefacto Android presente | app-debug.apk, 167.593.361 bytes; no acredita una publicación release |

Compilar no valida autenticación, conectividad real o funcionamiento del servidor contra PostgreSQL. En esta revisión no se ejecutó una nueva matriz Docker ni una compilación Android release.

## Hallazgos prioritarios

### P0: corregir antes de piloto con datos reales

1. **El dashboard falla y la vista puede mostrar ceros como si fueran datos válidos.** `apps/client/lib/core/services/dashboard_service.dart:125` usa `current_status = "maintenance"`; SQLite interpreta ese valor como identificador. Las 12 pruebas fallan con `no such column: "maintenance"`. Parametrizar la consulta o usar un literal SQL correcto. `features/dashboard/dashboard_screen.dart` usa `snapshot.data ?? DashboardSummary()` sin manejar `snapshot.hasError`; añadir estados de carga/error y reintento real. El gesto de refresco actual solo espera 300 ms.
2. **La duración JWT está mal tipada cuando viene del entorno.** `server/layer/src/modules/auth/auth.module.ts` usa `config.get<number>` sin convertir el string. Con el Compose actual, `JWT_ACCESS_TTL_SECONDS=900` puede generar tokens inmediatamente vencidos. Convertir y validar un entero positivo; probar expiración con configuración real.
3. **Logout permite revocar una sesión sin verificar el secreto del refresh token.** `auth.service.ts:logout` valida la forma del UUID y actualiza por ID; no compara el hash del secreto. Quien conozca un ID de sesión puede intentar cerrarla con un sufijo arbitrario. Verificar posesión del token y cubrir el caso con tests.
4. **Rotación de refresh no es atómica.** `refresh` lee/verifica y después actualiza sin comparar el hash anterior ni bloquear la fila. Dos solicitudes concurrentes pueden aceptar el mismo token y producir resultados inconsistentes. Usar transacción/bloqueo o actualización condicional y validar filas afectadas.
5. **Aislamiento por organización incompleto.** Existen columnas workspaceId, pero consultas como `WorkerRepository.watchAllWorkers/getWorkerById` no filtran por workspace. `LocalStorageService` aún escribe con el workspace predeterminado. Antes de importar datos de varios socios, todas las lecturas, escrituras, relaciones y agregados necesitan contexto de organización y pruebas negativas de acceso cruzado.

Los hallazgos de autenticación afectan a la API si se conserva como control de identidades. Si el piloto usa provisión administrativa directa de NATS, mantener esa API fuera de Internet hasta corregirla; no es obligatorio desplegarla para operar el buzón.

### P1: sincronización y seguridad pendientes

- El servidor implementa auth y health. No hay módulos operativos de sincronización, invitaciones/aceptación, dispositivos o concesión de permisos.
- Flutter no tiene transporte NATS/JetStream, motor de sincronización, configuración de endpoint ni flujo de autenticación remoto. `SyncQueueRepository` solo encola y consulta pendientes; su integración de negocio aparece en mantenimiento, no en todos los repositorios.
- Faltan inbox persistente, idempotencia de aplicación, reintentos, recibos, resolución de conflictos, snapshot inicial y recuperación tras caducidad de mensajes.
- Faltan cifrado de extremo a extremo en el cliente, almacenamiento seguro de claves, distribución/rotación de claves y revocación. TLS no sustituye este cifrado.
- El padrón contable de socios existente no equivale a miembros aceptados de una organización. Deben ser conceptos separados.
- No hay Compose/configuración NATS de producción, ACL por dispositivo, certificados o renovación automatizada dentro de deploy.
- La API no tiene limitación de intentos de login en el código revisado; el guard JWT tampoco consulta revocación de sesión. Definir si el cierre invalida inmediatamente accesos o espera su expiración, y probarlo.

## VPS: propuesta de subdominio y puertos

Usar **sync.<dominio-propio>** para el buzón; por ejemplo `sync.decolumax.com` solo si ese dominio pertenece al proyecto. No se verificó su propiedad/disponibilidad. DNS A hacia la IPv4 del VPS; AAAA solo con IPv6 y firewall correctamente configurados.

Para el primer piloto Android de mínimo consumo: NATS con TLS nativo en 4222 y volumen persistente. Validar primero que el cliente Dart elegido cubra JetStream, TLS, reconexión y ACK. Reservar `api.<dominio-propio>` únicamente si se mantiene la API de control.

| Servicio | Puerto del contenedor | Publicación en VPS propuesta | Uso de la app |
|---|---:|---|---|
| NATS con TLS nativo | 4222/TCP | `4222:4222`, protegido por TLS y credenciales/ACL | Conexión saliente a sync.<dominio>:4222 |
| Monitor NATS | 8222/TCP | Omitir o `127.0.0.1:8222:8222` | Ninguno |
| Cluster NATS | 6222/TCP | No publicar ni habilitar para un nodo | Ninguno |
| API actual, si se conserva | 3000/TCP | Ya usa `127.0.0.1:3000:3000` | HTTPS por proxy en 443, nunca 3000 público |
| PostgreSQL actual, si se conserva | 5432/TCP | Solo red Docker; Compose ya evita publicarlo | Ninguno |
| Proxy HTTP existente, si se utiliza | 443/TCP | Público | API HTTPS o alternativa NATS WSS |

La app móvil **no abre puertos entrantes**, no necesita IP pública ni redirección de puertos en el teléfono. El servidor conserva mensajes cifrados para destinatarios offline; no es P2P directo estricto.

Alternativa para Web o redes que restrinjan 4222: `wss://sync.<dominio>:443`. Configurar, por ejemplo, listener WebSocket NATS 8080 accesible solo al proxy existente; este termina TLS y reenvía WebSocket. Si el proxy corre en Docker, usar red compartida y nombre de servicio, no su propio localhost. Si corre en el host, publicar `127.0.0.1:8080:8080`. Con VPS dedicado y 443 libre también puede servirse WSS/TLS desde el propio NATS, sin otro contenedor. Estas alternativas requieren configuración y validación del cliente; no están implementadas.

No se puede asignar el mismo IP:443 a dos contenedores independientes. Un subdominio adicional por sí solo no resuelve esa colisión. Para TLS nativo en 4222, usar DNS directo; un proxy HTTP convencional no transporta automáticamente NATS TCP.

TLS requiere certificado válido, clave montada en solo lectura, renovación y recarga verificadas. Puede renovarse mediante DNS-01 sin abrir 80; HTTP-01 requiere el servicio de validación en 80. Credenciales distintas por dispositivo, permisos mínimos de publicación/lectura/ACK y administración fuera de las apps. No publicar el monitor en Internet.

Referencias: [NATS WebSocket](https://docs.nats.io/learn/websocket/), [publicación de puertos Docker](https://docs.docker.com/engine/network/port-publishing/).

## Recursos y persistencia

La referencia histórica probada es `nats:2.15.0-scratch`, límite **256 MiB / 0,50 CPU**, volumen JetStream en disco. Elegir versión mantenida y fijar digest tras validar el despliegue definitivo. `scratch` carece de shell/curl: no copiar healthchecks basados en ellos.

El ensayo anterior observó un pico muestreado de 123,2 MiB, sin TLS ni credenciales separadas. **No valida un límite de 150 MiB ni de 224 MiB en producción.** Si el requisito estricto es menos de 250 MiB, repetir con 224 MiB, TLS, ACL individuales, desconexiones y retención llena antes de aprobarlo. El límite es del contenedor; OS, Docker y proxy consumen aparte.

JetStream almacena archivos en volumen: no necesita PostgreSQL, pero sí almacenamiento persistente. Como punto de ensayo, conservar cuota global 900 MB, stream 400 MB y TTL 7 días de la matriz; ajustar al volumen real, adjuntos y plazo máximo offline. Reservar espacio adicional para logs rotados y copias. DiscardNew no evita expiración por TTL; la app debe conservar outbox, mostrar cuota agotada y recuperar mediante snapshot cuando corresponda.

Probar restauración de volumen/control y pérdida de energía. El SIGKILL anterior al proceso no acredita durabilidad ante apagado del host. Retener mensajes temporalmente tampoco sustituye el respaldo empresarial.

El Compose API + PostgreSQL actual fija techos de 1536 MiB en perfil normal y 896 MiB en economy; no cumple el objetivo de buzón único menor de 250 MiB. No desplegar ambos modelos por inercia.

## App móvil: funcionalidades, vistas y distribución

Implementados localmente: obras, mantenimiento/visitas, clientes/socios, trabajadores/jornales, compras/proveedores, inventario, herramientas, cobros/pagos/gastos/capital, calendario, notificaciones, respaldo JSON y metadatos de adjuntos. Su presencia y pruebas no acreditan aún sincronización ni disponibilidad remota de archivos.

La organización visual actual es adecuada como base: cinco destinos (Inicio, Obras, Mantto., Finanzas, Más), NavigationBar en móvil y NavigationRail en pantallas grandes. Más agrupa módulos secundarios. Finanzas usa cinco pestañas desplazables. Hay tema Material 3 oscuro y componentes comunes de estado; conviene aplicarlos consistentemente antes de rediseñar.

Pendientes de interfaz:

1. Organización activa, invitación, aceptación y dispositivos autorizados.
2. Indicador discreto de sincronización en Inicio y detalle en Más: guardado local, enviado al buzón, aplicado por socio, pendientes, errores y última conexión por dispositivo.
3. Conflictos con ambas versiones y resolución explícita; adjuntos pendientes y recuperación por historial vencido.
4. Dashboard con carga/error reales. No presentar ceros por fallo de consulta.
5. Prueba visual de formularios con teclado, texto grande, nombres largos, orientación y listas extensas; las pruebas responsive existentes no cubren todas esas combinaciones ni contraste/TalkBack.
6. Unificar la marca: launcher y MaterialApp aún muestran Mantenimientos/Mantenimiento & Gastos, mientras navegación muestra DECOLUMAX. En Versión, priorizar versión/soporte y trasladar rutas de compilación y archivos internos a diagnóstico técnico.

Publicación Android pendiente:

- El manifest principal no declara INTERNET. Añadirlo al integrar red y comprobar el manifest combinado de release.
- `build.gradle.kts` firma release con la clave debug. Configurar clave de distribución y custodia; si hay instalaciones existentes, decidir cómo conservar datos/identidad antes de cambiar firma o applicationId.
- Generar APK/AAB release, verificar versión y metadatos contra el paquete real, y probar actualización preservando Drift.
- Probar dos teléfonos reales, redes móviles, suspensión/Doze, reconexión y permisos de notificaciones. No prometer sincronización continua en segundo plano.

## Arquitectura y orden de ejecución

La separación features/core/repositorios/servicios es aprovechable. El punto a refactorizar es `LocalStorageService`: singleton que mezcla caché, acceso a datos y notificaciones; múltiples mutaciones recargan todas las colecciones y notifican globalmente. Migrar gradualmente a consultas reactivas acotadas por workspace, inyección de dependencias y transacciones dominio + outbox. Medir antes de introducir más capas.

| Entrega / commit propuesto | Criterio de aceptación |
|---|---|
| fix(client): restore dashboard queries and error states | Suite Flutter completa verde; un fallo de BD aparece como error, nunca como saldo cero |
| fix(auth): validate token lifetime and session rotation | TTL real, logout inválido y refresh concurrente cubiertos por tests; solo necesario exponer API una vez resuelto |
| refactor(client): enforce workspace boundaries | Lecturas/escrituras y relaciones aisladas; tests con dos organizaciones |
| feat(sync): persist journal inbox and encrypted transport | Dos clientes Flutter intercambian sin duplicar efectos; ACK posterior al commit local |
| feat(identity): approved devices and scoped access | Alta/aceptación/revocación, claves y pruebas de denegación cruzada; provisión manual admisible para piloto |
| feat(client): sync status conflicts and recovery | Usuario distingue estado local, buzón y aplicación remota; snapshot y recuperación ensayados |
| chore(deploy): secure NATS mailbox | Compose reproducible, TLS renovable, ACL, cuotas, volumen, logs y restauración; memoria medida con seguridad activa |
| chore(android): signed pilot release | Instalación/actualización y pruebas de dos socios en dispositivos físicos |

Identidad/permisos y transporte deben integrarse antes del intercambio con datos reales. Replicar primero un catálogo sencillo; después agregados de compras, stock y dinero con conflictos y conciliación. El transporte P2P directo es opcional y posterior.

Esta revisión documenta hallazgos y pruebas; no modifica lógica de negocio, autenticación, configuración del VPS ni la UI existente. La preparación completa exige cerrar los criterios anteriores.
