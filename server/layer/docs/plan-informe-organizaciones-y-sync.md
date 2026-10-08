Warning: truncated output (original token count: 13952)
Total output lines: 474

# Plan-informe: organizaciones, socios y sincronizaciÃ³n segura

**Fecha:** 7 de octubre de 2026

**Estado:** implementaciÃ³n en curso. La primera entrega local agrega identidad global, organizaciones y cambio seguro de contexto. Requiere migraciÃ³n y despliegue antes de estar disponible en VPS.
**Base:** informe de despliegue de la API del 7 de octubre, revisiÃ³n del cÃ³digo en `server/layer` y cliente Flutter.

## Estado de avance

| Entrega | Estado local | Pendiente para uso real |
|---|---|---|
| Seguridad de autenticaciÃ³n | LÃ­mites persistentes, auditorÃ­a y verificaciÃ³n de sesiÃ³n implementados | Desplegar migraciones `003` y `004` y verificar en VPS |
| Identidad global | MigraciÃ³n `005` consolida cuentas por correo y conserva membresÃ­as existentes | Revisar duplicados de correo y aplicar con backup |
| Organizaciones | API lista, crea, consulta y actualiza organizaciones; Flutter permite listar, crear, editar y cambiar entre ellas | Desplegar backend, migraciÃ³n `005` y probar con cuentas controladas |
| Miembros e invitaciones | DiseÃ±o y contratos documentados | Desarrollar endpoints y flujo de cÃ³digo de un solo uso |
| Dispositivos | SesiÃ³n ligada a dispositivo | Solicitud, aprobaciÃ³n, listado y revocaciÃ³n |
| SincronizaciÃ³n de negocio | Login, pull e inbox cifrado | Outbox cifrado, entrega entre dos clientes, descifrado y aplicaciÃ³n idempotente |

La migraciÃ³n `005_global_user_identities.sql` aborta de forma intencional si encuentra un mismo correo asociado a hashes de contraseÃ±a diferentes. En ese caso se requiere resolver la identidad manualmente antes de aplicarla; no se fusionan contraseÃ±as de forma silenciosa.

## 1. Resumen ejecutivo

La infraestructura de transporte estÃ¡ desplegada: Nginx Proxy Manager publica la API HTTPS, NestJS estÃ¡ conectado a PostgreSQL y NATS JetStream, y la app se conecta a la API sin recibir credenciales NATS. La API tiene autenticaciÃ³n bÃ¡sica, sesiones y endpoints `sync/push` y `sync/pull`. La revisiÃ³n del despliegue encontrÃ³ cero organizaciones y usuarios; por ahora no se puede iniciar sesiÃ³n sin crear el primer `owner` con `bootstrap-admin.ts`.

La primera entrega de administraciÃ³n de organizaciones ya estÃ¡ implementada localmente: una identidad de correo puede tener membresÃ­as en varias empresas; la persona puede listar, crear, editar y cambiar de organizaciÃ³n desde Flutter. El cambio revoca la sesiÃ³n anterior y emite otra vinculada a la membresÃ­a destino. Esta versiÃ³n no estÃ¡ desplegada y requiere ejecutar la migraciÃ³n `005` antes de iniciar la API nueva.

TodavÃ­a faltan el alta autogestionada de cuentas, invitaciones de socios, administraciÃ³n de otros miembros y dispositivos, intercambio de claves, publicaciÃ³n automÃ¡tica del outbox Flutter y aplicaciÃ³n idempotente de operaciones recibidas a las tablas de negocio. El inbox actual conserva sobres cifrados y cursores, pero eso no significa que los registros empresariales ya se repliquen.

**RecomendaciÃ³n:** conservar un **monolito modular NestJS** para el plano de control, PostgreSQL para identidades y permisos, y NATS JetStream como buzÃ³n de transporte cifrado. En Flutter, mantener el patrÃ³n local-first con repositorios, servicios y vistas-modelo. No separar microservicios ni retirar PostgreSQL durante esta fase: eso aumentarÃ­a la operaciÃ³n y no resolverÃ­a la ausencia de flujos de producto.

## 2. Estado observado y lÃ­mites

| Ãrea | Ya existe | Pendiente antes del uso real |
|---|---|---|
| Despliegue | API HTTPS, NPM, PostgreSQL y NATS; health y readiness correctos | Vigilar backups, cuotas, renovaciÃ³n de secretos y restauraciÃ³n probada |
| Identidad | En VPS: login por `workspaceSlug`/email/contraseÃ±a, refresh, logout, `/auth/me`, Argon2id. En local: lÃ­mites de login, validaciÃ³n de sesiÃ³n, auditorÃ­a y cambio de organizaciÃ³n | Desplegar/verificar cambios y migraciones; alta de cuenta, correo verificado y recuperaciÃ³n |
| OrganizaciÃ³n | Local: identidad global y API para listar/crear/consultar/actualizar organizaciones; Flutter para listar/crear/editar/cambiar | Aplicar migraciÃ³n `005` y desplegar; luego membresÃ­as e invitaciones |
| Sesiones/dispositivos | SesiÃ³n ligada a `device_id`; refresh hash en DB | Registro y aprobaciÃ³n de dispositivo, lista, revocaciÃ³n efectiva y expiraciÃ³n de permisos antiguos |
| Transporte sync | `push`/`pull` autenticados; relay JetStream; deduplicaciÃ³n de publicaciÃ³n | Pull segmentado por destinatario, ack de aplicaciÃ³n, aislamiento de buzones y backpressure |
| Flutter | Login, refresh, logout, pull, inbox/cursor Drift y envÃ­o de sobre ya cifrado | Generar/custodiar claves, cifrar outbox, publicar automÃ¡ticamente, descifrar y aplicar cambios |
| OperaciÃ³n de datos | JetStream persistente con lÃ­mites globales | Cuotas por organizaciÃ³n, monitorizaciÃ³n de disco, backups y polÃ­tica probada de recuperaciÃ³n |

La API actual usa una identidad runtime NATS compartida y un stream compartido; el pull explora hasta 2.000 secuencias por llamada y filtra por workspace en el servidor. Es aceptable para integraciÃ³n/piloto acotado, no como estrategia de escalado de mÃºltiples organizaciones.

Hay documentaciÃ³n anterior que todavÃ­a describe la API como no desplegada. Para el estado operativo prevalece el informe del 7 de octubre de 2026; al iniciar cada fase se debe corregir la documentaciÃ³n contradictoria y enlazar las evidencias de VPS sin registrar secretos.

## 3. Arquitectura objetivo y patrones

### 3.1 Plano de control y plano de datos

```text
Flutter (DB local + claves) --HTTPS/JWT--> API NestJS --TLS/runtime--> NATS JetStream
             |                              |                                |
             | operaciones cifradas         | PostgreSQL                     | buzones cifrados
             | y aplicaciÃ³n local            | cuentas, organizaciones,      | retenciÃ³n limitada
             |                              | membresÃ­as, dispositivos      |
```

- **Plano de control (NestJS + PostgreSQL):** crea organizaciones, autentica cuentas, gestiona membresÃ­as, invitaciones, claves pÃºblicas, dispositivos, autorizaciones y auditorÃ­a. Nunca guarda claves privadas ni datos de negocio en claro.
- **Plano de datos (JetStream):** almacena y reenvÃ­a sobres opacos cifrados. No es la fuente de verdad para permisos, roles o saldos empresariales.
- **Cliente local-first (Flutter + Drift):** cada dispositivo mantiene su base local y un journal de operaciones. La API no reemplaza la base local.
- **TLS y cifrado E2E tienen propÃ³sitos distintos:** TLS protege cada enlace; el cifrado de extremo a extremo impide que el VPS lea el contenido del sobre.

### 3.2 Patrones propuestos

1. **Monolito modular / bounded contexts:** separar `identity`, `organizations`, `memberships`, `invitations`, `devices`, `authorization`, `sync` y `audit` como mÃ³dulos NestJS con interfaces explÃ­citas. Desplegarlos juntos mientras la escala sea pequeÃ±a. Evitar microservicios prematuros.
2. **Clean Architecture ligera / puertos y adaptadores:** controllers traducen HTTP; casos de uso expresan acciones; repositorios esconden PostgreSQL; `NatsMailboxPort` es un adaptador de transporte. Facilita probar los casos de uso sin VPS y cambiar lÃ­mites sin dispersar lÃ³gica en controladores.
3. **AutorizaciÃ³n RBAC + relaciones:** roles definen las capacidades generales (`owner`, `admin`, `member`); membresÃ­a aceptada, workspace, dispositivo aprobado y relaciÃ³n de socio determinan el acceso concreto. Denegar por defecto y verificar en el servidor en cada endpoint.
4. **Invitaciones como credenciales de un solo uso:** token aleatorio de alta entropÃ­a, asociado a workspace y rol mÃ­nimo, almacenando solo su hash, con expiraciÃ³n, revocaciÃ³n y consumo atÃ³mico. Un cÃ³digo no es la contraseÃ±a de la organizaciÃ³n ni una credencial permanente.
5. **Outbox local + inbox idempotente:** persistir el cambio de negocio y su operaciÃ³n en una misma transacciÃ³n Drift; reintentar la publicaciÃ³n hasta obtener confirmaciÃ³n del broker. En el receptor, persistir primero el sobre y el cursor; aplicar una vez lÃ³gica con `operationId` estable y conservar conflictos recuperables.
6. **Puertos/adaptadores para transporte:** `SyncTransport` abstrae HTTPS/NATS y habilita un transporte directo futuro sin cambiar el formato de operaciones. P2P directo queda fuera del MVP y no es requerido para que el buzÃ³n funcione.
7. **PolÃ­ticas testeables:** mantener las reglas de autorizaciÃ³n en servicios/casos de uso y probar la matriz usuario-rol-acciÃ³n-organizaciÃ³n-dispositivo. No depender solo de ocultar botones en Flutter.

Las recomendaciones de Flutter apoyan separar UI y datos y usar repositorios y servicios; OWASP recomienda mÃ­nimo privilegio, denegaciÃ³n por defecto y verificar permisos en cada peticiÃ³n. NestJS ofrece guards y mÃ³dulos para estructurar autenticaciÃ³n/autorizaciÃ³n y limitaciÃ³n de tasa. JetStream proporciona consumers durables con ACK explÃ­cito; la aplicaciÃ³n debe asumir reentrega y ser idempotente.

### 3.3 Identidad y pertenencia

Para cumplir el objetivo de no crear credenciales duplicadas al colaborar con varias empresas, se recomienda evolucionar gradualmente de `users.workspace_id` a:

- `users`: identidad global Ãºnica por email normalizado, contraseÃ±a hash, estado y verificaciÃ³n.
- `workspaces`: organizaciÃ³n y estado.
- `workspace_memberships`: vÃ­nculo user-workspace con rol/estado, fechas y restricciones Ãºnicas.
- `user_sessions`: sesiÃ³n vinculada a usuario, workspace activo y dispositivo; el servidor valida que la membresÃ­a siga activa.

Esto exige migraciÃ³n y cambio de login. La app puede autenticar email/contraseÃ±a y luego seleccionar una organizaciÃ³n; alternativamente, usar slug/cÃ³digo de organizaciÃ³n como contexto de login. No se debe conservar simultÃ¡neamente dos modelos de identidad ambiguos. Antes de migrar, respaldar datos y probar la transiciÃ³n sin usuarios productivos (el informe indica que aÃºn no hay ninguno).

## 4. Flujos funcionales esperados

### 4.1 Crear organizaciÃ³n y cuenta inicial

1. Persona ingresa nombre de organizaciÃ³n, email, contraseÃ±a y nombre visible.
2. API normaliza y valida email, verifica polÃ­tica de contraseÃ±a, limita intentos y crea identidad, workspace, membresÃ­a `owner` y registro de auditorÃ­a en una transacciÃ³n.
3. EnvÃ­a verificaciÃ³n de correo mediante proveedor configurado; la organizaciÃ³n queda en estado `pending_verification` hasta completar el flujo.
4. Tras verificar, habilita login y crea sesiÃ³n del dispositivo. El slug es un localizador, nunca un secreto.
5. Conserva `bootstrap-admin.ts` como recuperaciÃ³n operativa controlada, con auditorÃ­a y sin uso cotidiano.

No abrir alta pÃºblica hasta que haya verificaciÃ³n de correo, rate limiting y alertas de abuso. Para el piloto cerrado se puede crear el primer owner manualmente y usar el mismo flujo de gestiÃ³n posterior.

### 4.2 Invitar y aceptar socios

1. Owner/admin genera invitaciÃ³n a email y rol permitido; API genera token aleatorio de un solo uso, guarda hash, workspace, creador, expiraciÃ³n y lÃ­mites de uso.
2. Flutter comparte enlace o cÃ³digo; la invitaciÃ³n no entrega acceso ni secretos NATS.
3. Invitado se autentica/crea identidad, verifica email y acepta. La API consume la invitaciÃ³n una sola vez y crea membership `pending` o `active` segÃºn la polÃ­tica acordada.
4. Los socios confirman la asociaciÃ³n; sÃ³lo `accepted` autoriza lectura/escritura de datos. Rechazo, expiraciÃ³n o revocaciÃ³n invalidan el token.
5. El servidor audita creador, aceptante, tiempos, cambios de rol y revocaciones, sin registrar el token completo.

### 4.3 Aprobar y revocar dispositivos

Cada instalaciÃ³n crea un `deviceId` estable y claves propias. Un dispositivo nuevo inicia `pending`, muestra nombre, plataforma y huella/QR para aprobaciÃ³n independiente. Owner/admin puede aprobar, bloquear o revocar. La API invalida sesiones y permisos futuros; Flutter detiene el transporte y marca la clave como revocada. Revocar no puede borrar sobres ya descifrados por un dispositivo ni retirar una copia offline; la UI debe explicarlo.

### 4.4 Sincronizar un cambio de negocio

1. La acciÃ³n local escribe dominio + operaciÃ³n versionada en una sola transacciÃ³n Drift.
2. `SyncEngine` selecciona operaciones pendientes y verifica membresÃ­a, destinatarios y Ã©poca de claves.
3. Flutter serializa payload canÃ³nico, cifra y firma con claves del dispositivo; el API valida tamaÃ±o, versiÃ³n y claims sin descifrar.
4. NATS persiste el sobre; API confirma `accepted` sÃ³lo tras el ack de publicaciÃ³n.
5. Dispositivo destino descarga por su cursor/consumer, persiste inbox y cursor, valida firma y contexto, descifra y aplica en transacciÃ³n local.
6. `operationId` evita duplicados. Operaciones incompatibles generan conflicto visible, no sobrescritura por hora del telÃ©fono ni orden de llegada.
7. Un recibo firmado distingue `received` de `applied`; el emisor conserva su operaciÃ³n hasta que el contrato de entrega estÃ© satisfecho.

Para dinero, compras e inventario no usar â€œlast write winsâ€. Definir comandos/agregados e invariantes; por ejemplo, movimientos de stock inmutables y ajustes compensatorios, y mostrar conflictos de disponibilidad offline.

## 5. Contrato inicial de autorizaciÃ³n

| AcciÃ³n | Owner | Admin | Member |
|---|---:|---:|---:|
| Cambiar organizaciÃ³n y transferir propiedad | SÃ­ | No | No |
| Invitar, cambiar rol y revocar membresÃ­as | SÃ­ | Limitado | No |
| Aprobar/revocar dispositivos | SÃ­ | SÃ­ (propuesta) | SÃ³lo sus propios dispositivos |
| Ver y operar datos empresariales | SÃ­ | SÃ­ | SegÃºn permisos de producto |
| Generar/revocar invitaciÃ³n | SÃ­ | SÃ­ | No (MVP) |
| Administrar claves de recuperaciÃ³n | SÃ­ con confirmaciÃ³n | No | Sus dispositivos |

La matriz es una propuesta inicial: codificarla como polÃ­ticas y pruebas antes de exponer endpoints. Las acciones sensibles requieren reautenticaciÃ³n; cambios de propiedad, eliminaciÃ³n de organizaciÃ³n y exportaciÃ³n de claves no deben quedar implÃ­citos en el rol `admin`.

## 6. Fases de desarrollo y criterios de salida

### Fase 0 â€” Congelar contrato y entorno de piloto

- Corregir documentaciÃ³n obsoleta del estado de despliegue.
- Crear workspace y owner de prueba mediante bootstrap; validar login, refresh, logout y `/auth/me` contra dominio pÃºblico desde Android/Web.
- Confirmar CORS, vencimientos de token, revocaciÃ³n de sesiÃ³n, readiness y que ningÃºn secreto NATS llega al bundle Flutter.
- **Salida:** pruebas HTTP documentadas, cuenta de prueba revocable y rollback conocido.

### Fase 1 â€” Seguridad base de identidad

- AÃ±adir throttling a nivel global y mÃ¡s estricto para login, refresh, verificaciÃ³n e invitaciones; limitar login por combinaciÃ³n de email normalizado + IP y tambiÃ©n por IP, con almacenamiento que resista reinicios y sin bloquear globalmente la cuenta por intentos de terceros.
- Respuestas de login y recuperaciÃ³n evitan enumeraciÃ³n; revisar polÃ­tica de contraseÃ±a, Argon2id, secretos JWT y logs sin tokens ni datos sensibles.
- El guard consulta y aplica revocaciÃ³n de sesiones/dispositivos en cada acciÃ³n protegida o mediante cachÃ© con frescura documentada.
- AÃ±adir eventos de auditorÃ­a para login fallido, Ã©xito, sesiÃ³n, cambio de rol, invitaciÃ³n, aprobaciÃ³n/revocaciÃ³n, push/pull y conflictos.
- **Salida:** pruebas de fuerza bruta, sesiones revocadas, concurrencia de refresh, autorizaciÃ³n cruzada deneg…5952 tokens truncated…acta y acciones tÃ¡ctiles; confirmar el origen CORS no cambia el contenido visible de la seguridad.
- **AnimaciÃ³n:** reutilizar `AppMotion`; transiciones breves para selecciÃ³n/expansiÃ³n, progreso para operaciones reales y sin animar estados de error repetidamente. Respetar â€œreducir movimientoâ€ y evitar que color/movimiento sean la Ãºnica seÃ±al.
- **Accesibilidad:** soporte de lector de pantalla, labels completos, contraste AA, foco teclado, escalado hasta 200 %, targets de 48 dp y orden lÃ³gico. Verificar tambiÃ©n textos largos traducibles y formatos locales de fecha/hora.

### 11.7 Componentes reutilizables a aÃ±adir

Colocar componentes de dominio compartidos bajo `apps/client/lib/features/organization/widgets/` y `features/sync/widgets/`, no dentro de pantallas especÃ­ficas:

- `OrganizationSummaryCard`, `WorkspaceSwitcher`, `RoleBadge`, `MembershipStatusChip`.
- `MemberListTile`, `InvitationCard`, `InviteCodePanel`, `InvitationExpiryLabel`.
- `DeviceCard`, `DeviceTrustBadge`, `FingerprintComparePanel`, `RevokeDeviceDialog`.
- `SyncStageIndicator` (local/enviado/recibido/aplicado), `SyncQueueSummary`, `LastSyncLabel`.
- `ConflictSummaryCard`, `ConflictFieldComparison`, `ConflictResolutionSheet`.
- `SecurityNotice`, `PermissionGate`, `EmptyStatePanel`, `InlineRetryState`.

Todos reciben estado/acciones como parÃ¡metros o desde un view-model y no hacen llamadas HTTP/NATS por su cuenta. Los botones y cards usan `Theme.of(context).colorScheme`; los textos y tooltips se definen una vez por mÃ³dulo. Mantener el acceso a datos en repositorios y la lÃ³gica de pantalla en view-model/controlador para que el patrÃ³n de presentaciÃ³n coincida con la arquitectura de Flutter.

### 11.8 Entregables visuales y revisiÃ³n antes de cerrar cada fase

1. Actualizar sitemap/wireframes en `docs/ux_v2.md` para incluir onboarding, administraciÃ³n de organizaciÃ³n, invitaciones, dispositivos, claves y conflictos; marcar quÃ© existe, es placeholder o queda futuro.
2. Definir tabla de rutas, permisos y CTA por vista junto con casos de loading/empty/error/offline.
3. Implementar tokens compartidos y componentes; no crear una paleta paralela.
4. Crear widget tests de permisos/acciones crÃ­ticas y layouts; comprobar textos grandes, pantalla estrecha, teclado y modo Web.
5. Revisar capturas de Android pequeÃ±o, Android grande y Web de escritorio; validar que los estados representen las respuestas reales del API.
6. Comprobar semÃ¡ntica/contraste y navegaciÃ³n con teclado/lector antes del lanzamiento.

**Criterio visual de terminado:** una persona puede crear/seleccionar empresa, comprender su rol, invitar y aceptar a un socio, reconocer dispositivos confiables, revocar acceso y diagnosticar por quÃ© una operaciÃ³n no se aplicÃ³ sin leer IDs tÃ©cnicos ni confundir â€œconectadoâ€ con â€œsincronizadoâ€.

### 11.9 Experiencia completa de consumo y administraciÃ³n

**Objetivo de esta revisiÃ³n:** que una persona pueda operar su negocio, administrar quiÃ©n participa y entender el estado de sus datos desde la misma aplicaciÃ³n. El Ã¡rea administrativa debe mostrar tareas accionables y su resultado, ademÃ¡s de formularios de configuraciÃ³n.

```mermaid
flowchart TD
    Inicio[Inicio: empresa activa y trabajo del dÃ­a] --> Selector[Selector de empresa]
    Inicio --> Mas[MÃ¡s]
    Inicio --> ResumenSync[Estado breve de sincronizaciÃ³n]
    Selector --> Empresa[Mi empresa]
    Mas --> Empresa
    Mas --> Cuenta[Mi cuenta]
    Empresa --> Miembros[Miembros y roles]
    Empresa --> Invitaciones[Invitaciones]
    Empresa --> Dispositivos[Dispositivos y verificaciÃ³n]
    Empresa --> Actividad[Actividad administrativa]
    ResumenSync --> Sync[SincronizaciÃ³n]
    Sync --> Operaciones[Operaciones y entregas]
    Sync --> Conflictos[Conflictos por resolver]
    Sync --> Recuperacion[RecuperaciÃ³n]
```

**Cabecera compartida:** nombre de la empresa activa, rol con etiqueta legible (Propietario/Administrador/Miembro), acceso al selector, indicador resumido de sincronizaciÃ³n y acceso a cuenta. En mÃ³vil priorizar empresa y estado; las acciones secundarias se despliegan en un menÃº. Conservar los destinos principales del negocio de la barra inferior para no desplazar Obras, Mantenimientos o Finanzas.

**Inicio de Mi empresa para owner/admin:** resumen de miembros activos y dispositivos aprobados, bandeja de solicitudes pendientes, invitaciones prÃ³ximas a vencer y actividad reciente. CTA principal â€œInvitar miembroâ€; cada solicitud lleva a una vista de detalle antes de autorizar. Un contador desconocido se muestra como â€œSin actualizarâ€, nunca como cero. No afirmar que un dispositivo estÃ¡ online sÃ³lo por tener una sesiÃ³n vigente: mostrar â€œÃšltimo contactoâ€ con fecha.

**Inicio de Mi empresa para member:** nombre de organizaciÃ³n, rol y permisos, responsable de contacto, estado de sus dispositivos e invitaciones que pueda aceptar. La UI deriva acciones del permiso efectivo; pertenecer a la empresa no da acceso a la gestiÃ³n de todos los dispositivos. El servidor vuelve a comprobar cada acciÃ³n.

**ComposiciÃ³n de escritorio:** navegaciÃ³n lateral existente, cabecera con empresa, lista principal y panel de detalle; filtros y paginaciÃ³n accesibles por teclado. Usar la misma selecciÃ³n/estado que mÃ³vil. Abrir una fila muestra detalle; aprobar/revocar es una acciÃ³n explÃ­cita y separada de seleccionar.

Wireframe orientativo de Mi empresa (los nÃºmeros sÃ³lo ilustran distribuciÃ³n; la implementaciÃ³n usa datos reales):

```text
Mi empresa Â· Decolumax                  Propietario   [Cambiar empresa]
Resumen  |  Miembros  |  Invitaciones  |  Dispositivos  |  Actividad

Miembros activos     Dispositivos aprobados     Solicitudes pendientes
        3                       4                         1

Requiere tu atenciÃ³n                                   [Invitar miembro]
Nuevo dispositivo Â· Android Â· Carlos              [Revisar solicitud]
InvitaciÃ³n pendiente Â· Ana Â· vence maÃ±ana             [Ver invitaciÃ³n]

Actividad reciente
Carlos aceptÃ³ la invitaciÃ³n                              Hoy, 10:15
Este dispositivo terminÃ³ de recibir cambios              Hoy, 10:10
```

Los eventos de sincronizaciÃ³n sÃ³lo aparecen en actividad si existe evidencia de entrega para ese dispositivo y el usuario tiene permiso. El wireframe no prueba que esas mÃ©tricas estÃ©n disponibles en la API actual.

### 11.10 Correspondencia entre vistas y API

Las rutas de alta/administraciÃ³n de esta tabla son **contratos propuestos pendientes**. Los endpoints existentes de autenticaciÃ³n y sync se conservan o versionan al migrar identidad; no se muestra Ã©xito simulado en pantallas sin backend.

| IntenciÃ³n del usuario | Consumo de API | Resultado visible y control necesario |
|---|---|---|
| Entrar y recuperar sesiÃ³n | Login, refresh y `/auth/me` existentes; adaptar a identidad global | OrganizaciÃ³n, rol y capacidades efectivos. El login deja de estar incrustado en una tarjeta de diagnÃ³stico. |
| Ver mis empresas / cambiar | Listado autorizado de organizaciones y selecciÃ³n de contexto, por implementar | Cabecera y consultas cambian juntas; mostrar progreso mientras se prepara el contexto local. |
| Crear empresa | Alta de identidad si hace falta, creaciÃ³n de organizaciÃ³n y membership, por implementar | Resumen de la empresa creada y pasos pendientes. Si la persona ya tiene cuenta, no pedir otra contraseÃ±a ni crear otra identidad. |
| Administrar miembros | Listar/detallar membership, cambiar rol y revocar, por implementar | Lista actualizada tras confirmaciÃ³n del servidor. Impedir quitar/degradar al Ãºltimo owner; transferencia de propiedad requiere flujo dedicado. |
| Invitar / aceptar | Emitir, consultar estado, cancelar y consumir invitaciÃ³n, por implementar | Token sÃ³lo al emitir; expiraciÃ³n, estado y rol comprensibles. Doble tap/reintento no crea membresÃ­as duplicadas. |
| Aprobar dispositivo | Solicitud, prueba de posesiÃ³n, detalle y aprobaciÃ³n/revocaciÃ³n, por implementar | Huella y propietario antes de aprobar; el estado confiable exige completar verificaciÃ³n e intercambio de claves. |
| Sincronizar | `push`/`pull` existentes mÃ¡s motor E2E, procesamiento local y recibos pendientes | Progreso por etapa. â€œAplicadoâ€ requiere confirmaciÃ³n local o recibo del destino identificado. |
| Ver disponibilidad | `/health` y `/health/ready`, sesiÃ³n y estado del motor | Disponibilidad HTTPS separada de permisos, claves y entrega. Retirar el sondeo TCP/TLS directo a NATS del flujo habitual de la app. |
| Resolver conflicto | Caso de uso local que genera una operaciÃ³n de resoluciÃ³n | Conserva las versiones comparadas y muestra cuÃ¡ndo la resoluciÃ³n llegÃ³ a otros dispositivos. |
| Revisar actividad | Consulta paginada autorizada, por implementar | Actor, acciÃ³n, resultado y fecha, sin secretos. Filtros por miembro, dispositivo y periodo. |

Cada mÃ³dulo expone intents concretos como `createOrganization`, `acceptInvitation`, `changeRole`, `approveDevice` y `retrySync`. View-models coordinan repositorios y publican estados; widgets reciben callbacks. Evitar un controlador global que contenga todas las reglas de empresa, criptografÃ­a y navegaciÃ³n.

### 11.11 Comportamientos que completan la experiencia

- **Cambio seguro de empresa:** detener tareas del contexto saliente, invalidar respuestas HTTP atrasadas y cargar repositorios/cursores/claves del destino. La cola pendiente de la empresa anterior se conserva con su workspace; nunca se renombra ni se envÃ­a a la empresa seleccionada. Los registros locales anteriores a la asociaciÃ³n requieren una migraciÃ³n/importaciÃ³n explÃ­cita, no una reasignaciÃ³n automÃ¡tica al hacer login.
- **Modo offline:** permitir las operaciones de negocio soportadas por el dominio local. Crear membresÃ­as, aprobar dispositivos y cambiar roles requieren respuesta del servidor; mostrar el motivo y conservar borradores, sin presentar aprobaciones pendientes como permisos efectivos.
- **SesiÃ³n vencida:** ofrecer reautenticaciÃ³n conservando cambios locales. Logout revoca/borra tokens segÃºn el flujo, pero no ejecuta un borrado silencioso de la base empresarial. El borrado local es otra acciÃ³n explÃ­cita con sus consecuencias.
- **PaginaciÃ³n y consumo:** listas paginadas, bÃºsqueda con debounce, una carga activa por intenciÃ³n y lÃ­mite de concurrencia del motor. Actualizar al abrir, volver al primer plano, completar una mutaciÃ³n o usar â€œActualizarâ€; el polling continuo por cada pantalla no es necesario. Cancelar las cargas al salir de la vista cuando proceda.
- **CachÃ© autorizada:** indexar datos administrativos por usuario y workspace; mostrar la fecha de actualizaciÃ³n. Una respuesta nueva de revocaciÃ³n/403 invalida las acciones y cachÃ©s correspondientes. Los permisos cacheados sirven para presentaciÃ³n, no para conceder acceso nuevo.
- **Errores recuperables:** asociar 401 a renovaciÃ³n/relogin, 403 a permiso insuficiente, 409 al conflicto de estado especÃ­fico devuelto por la API, 429 a espera indicada por el servidor y fallos de red a reintento. Validaciones aparecen junto al campo; el estado global se anuncia con banner. No borrar un formulario por error de red.
- **Resultado incierto:** tras timeout de una acciÃ³n sensible, consultar su resultado con la misma identidad de operaciÃ³n antes de ofrecer repetirla. Evitar generar varias invitaciones o duplicar organizaciones por doble tap.
- **InvitaciÃ³n desde enlace:** conservar intenciÃ³n durante login y verificaciÃ³n, volver al resumen de la empresa invitante y aceptar sÃ³lo tras confirmaciÃ³n explÃ­cita. Ofrecer entrada manual de cÃ³digo cuando no exista cÃ¡mara o el enlace no abra la app; quitar el secreto de la URL despuÃ©s de capturarlo y no enviarlo a analÃ­tica.
- **Permisos por tarea:** controles de administraciÃ³n visibles sÃ³lo para quien tiene la acciÃ³n; acciones que dependen de red o verificaciÃ³n muestran motivo de indisponibilidad. La UI no debe ocultar que falta aprobar un dispositivo ni confundirlo con un fallo de contraseÃ±a.
- **Privacidad de diagnÃ³sticos:** dominio HTTPS/configuraciÃ³n tÃ©cnica se limita a detalles de soporte. No solicitar al usuario host NATS, stream, consumidor ni credenciales runtime. La pantalla normal habla de empresa, registros, dispositivos y entregas.

### 11.12 Secuencia de entrega visual y funcional

| Entrega | Alcance vertical (vista + lÃ³gica + API) | DemostraciÃ³n de cierre |
|---|---|---|
| UI-1 | Shell con empresa activa, acceso independiente y estado HTTPS real | Login existente funciona; el usuario distingue sesiÃ³n de sincronizaciÃ³n y puede abrir Cuenta/Mi empresa/Sync. |
| UI-2 | Crear/seleccionar organizaciÃ³n y administrar perfil | Alta real y cambio de empresa sin mezcla de datos; migraciÃ³n de identidad cubierta. |
| UI-3 | Miembros, invitaciones y aceptaciÃ³n con permisos | Dos cuentas completan invitaciÃ³n y aceptaciÃ³n; token repetido/expirado y Ãºltimo owner estÃ¡n controlados. |
| UI-4 | Dispositivos, QR/huella, aprobaciÃ³n y revocaciÃ³n | Segundo dispositivo se autoriza y obtiene acceso segÃºn el protocolo; dispositivo revocado pierde acceso futuro. |
| UI-5 | Estado de operaciones, detalle de entrega y conflictos | Una operaciÃ³n real viaja cifrada y se aplica una vez; un conflicto real puede revisarse y resolverse. |
| UI-6 | Actividad, recuperaciÃ³n y revisiÃ³n visual de release | Flujo completo mÃ³vil/Web con teclado, texto grande, offline, errores, restauraciÃ³n y capturas verificadas. |

La secuencia visual se ejecuta junto a las fases tÃ©cnicas 0â€“8; crear la pantalla no cierra el mÃ³dulo si no existe su caso de uso y contrato API. Primero revisar una composiciÃ³n mÃ³vil y otra Web con datos de prueba claramente identificados; despuÃ©s conectar las acciones y validar con cuentas reales del piloto.

## 12. Referencias tÃ©cnicas consultadas

- NestJS, autenticaciÃ³n y limitaciÃ³n de intentos: [Authentication](https://docs.nestjs.com/security/authentication), [Rate Limiting](https://docs.nestjs.com/security/rate-limiting), [Authorization](https://docs.nestjs.com/security/authorization).
- Flutter, separaciÃ³n UI/datos y repositorios: [Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations), [Guide to app architecture](https://docs.flutter.dev/app-architecture/guide).
- NATS, persistencia, consumers durables y ACK: [JetStream concepts](https://docs.nats.io/concepts/jetstream), [JetStream deep dive](https://docs.nats.io/learn/jetstream/).
- OWASP, autorizaciÃ³n y multi-tenancy: [Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html), [Multi-Tenant Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html), [Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).
- CriptografÃ­a mÃ³vil: [Android Keystore](https://developer.android.com/privacy-and-security/keystore), [Libsodium authenticated encryption](https://doc.libsodium.org/public-key_cryptography/authenticated_encryption). Estas referencias orientan requisitos; no seleccionan automÃ¡ticamente el protocolo E2E final.
- MensajerÃ­a fiable: [Transactional Outbox pattern](https://learn.microsoft.com/en-us/azure/architecture/databases/guide/transactional-out-box-cosmos).
- Documentos de producto que complementan este informe: [`migracion-sync-cifrado.md`](migracion-sync-cifrado.md), [`sync-api.md`](sync-api.md), [`../../../docs/sync_protocol_v3.md`](../../../docs/sync_protocol_v3.md).

