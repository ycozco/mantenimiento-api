# Opciones de transporte y optimización del sync cifrado

Consulta: 2026-10-05, America/Lima. Esta evaluación incluye la prueba sintética local comparativa ([reporte-prueba-local-buzones.md](reporte-prueba-local-buzones.md)), el reensayo de recuperación NATS ([reporte-prueba-nats-ampliada.md](reporte-prueba-nats-ampliada.md)) y la matriz 3–10 socios con picos de recursos ([reporte-matriz-nats-3-a-10-socios.md](reporte-matriz-nats-3-a-10-socios.md)). No se usaron Flutter ni Drift; las mediciones son de laboratorio, no un benchmark de producción. Los objetivos de recursos de este documento tampoco son mediciones.

Plan funcional y orden de migración: [migracion-sync-cifrado.md](migracion-sync-cifrado.md).

## 1. Recomendación según el caso

| Necesidad | Candidato | Límite que determina la elección |
|---|---|---|
| A deja cambios y B los recoge después, sin DB externa | **NATS JetStream** | Requiere volumen, cuotas, cifrado en Flutter y control de acceso |
| Mensajes pequeños por MQTT con persistencia de sesiones | Mosquitto | Persistencia/ACK de protocolo no equivalen a aplicación duradera en Drift |
| Directo Android↔Android y Android↔Web por Internet | `flutter_webrtc`, DataChannel | Algunas redes exigen relay; directo estricto debe aceptar fallos de conexión |
| Dispositivos en una LAN/hotspot | Protocolo local inspirado en LocalSend | Firewall/aislamiento Wi-Fi y listener nativo; no es SDK de replicación de DB |
| Android cercanos sin Internet | Nearby Connections | Permisos, Google Play services y prueba con dispositivos físicos |
| QUIC nativo y transferencia de blobs | Iroh | Integración Flutter más reciente, toolchain Rust y relay por defecto a revisar |

P2P directo por sí solo no entrega a un destinatario apagado. Un TURN reenvía tráfico de sesiones activas; no constituye un buzón offline. Con dos teléfonos, deben coincidir conectados; con más peers autorizados, puede servir otro que conserve los cambios.

La recomendación de empezar por JetStream es una inferencia de sus primitivas de persistencia/ACK y de la necesidad del usuario de entrega diferida; no afirma que sea el de menor RSS entre todos los productos.

## 2. Servicios e imágenes del buzón

### NATS JetStream

Proyecto: [nats-io/nats-server](https://github.com/nats-io/nats-server). Imagen oficial: familia **`nats:<versión>-scratch`**, o Alpine para diagnóstico. `scratch` evita una distribución/shell en la imagen; no elimina el runtime del binario. Fijar versión y digest después del ensayo, no desplegar un tag flotante. El catálogo consultado incluye variantes scratch y Alpine. [Docker oficial](https://hub.docker.com/_/nats/), [Dockerfiles](https://github.com/nats-io/nats-docker).

JetStream está integrado en `nats-server`; con `storage=file` conserva mensajes en archivos y consumidores independientes. No necesita PostgreSQL, Redis ni MongoDB. Core NATS sin JetStream no resuelve entrega offline. [Documentación](https://docs.nats.io/concepts/jetstream).

Cliente candidato: [dart-nats/dart-nats](https://github.com/dart-nats/dart-nats), licencia MIT. Tiene transporte TCP/TLS y WebSocket y APIs JetStream. Validar en versión fijada: reconexión Android, WSS Web, ACK manual después del commit Drift, autenticación seleccionada, permisos de respuesta/ACK y límites de buffering. Como referencia de integración existe [nverbeek/nats_client_flutter](https://github.com/nverbeek/nats_client_flutter/releases); es una herramienta cliente, no el motor financiero de Decolumax.

No otorgar al cliente los permisos administrativos de un ejemplo de README. Un consumidor por dispositivo evita que dos socios se repartan mensajes que ambos necesitan. La aplicación sigue siendo responsable de autenticidad del autor, cifrado E2E, conflictos y deduplicación permanente.

### Eclipse Mosquitto

Imagen oficial: **`eclipse-mosquitto:<versión>`**. Persistencia, autenticación/ACL y soporte MQTT; candidato para comparar si se prioriza mensajería pequeña. [Imagen oficial](https://hub.docker.com/_/eclipse-mosquitto), [proyecto](https://github.com/eclipse-mosquitto/mosquitto).

La persistencia incorporada guarda sesiones/mensajes en `mosquitto.db`: es un archivo interno, aunque no haya un servidor de DB separado. La documentación distingue snapshots periódicos y alternativas de persistencia. Las colas pueden descartar mensajes al alcanzar límites. Por ello exigir sesiones persistentes, QoS adecuado, límites observables y recibos de aplicación; un PUBACK no prueba que el socio haya guardado el negocio. [Configuración](https://mosquitto.org/man/mosquitto-conf-5.html).

La alternativa de persistencia SQLite aparece desde 2.1 y sigue siendo almacenamiento embebido: no cumple una interpretación literal de «ninguna DB». [Plugin de persistencia](https://mosquitto.org/documentation/persistence/sqlite/).

Cliente: [shamblett/mqtt5_client](https://github.com/shamblett/mqtt5_client), Dart nativo y navegador. Su README enumera limitaciones de flujo; probar control de memoria y ACK del paquete concreto. El [plugin Dynamic Security](https://mosquitto.org/documentation/dynamic-security/) administra clientes/roles/ACL, pero no implementa las invitaciones empresariales ni el cifrado extremo a extremo.

Para una réplica nueva que nunca estuvo suscrita, no asumir que encontrará todo el historial. MQTT retained conserva el último mensaje por topic, no una cola de todas las operaciones. Este encaje requiere más reglas de recuperación que JetStream para el caso de Decolumax.

### Qué significa un solo contenedor

| Despliegue | Contenedores de aplicación | Funciones pendientes |
|---|---:|---|
| Broker + credenciales/ACL provisionadas manualmente | 1 | Asociación aprobada y registro inicial hechos por administrador; cifrado en Flutter |
| Broker + API de control con almacenamiento embebido | 2 | Migrar metadata/auth actual; automatizar invitación, aceptación y revocación |
| API actual + PostgreSQL + broker, durante transición | 3 | No es el objetivo mínimo; permite probar sin retirar autenticación antes de tiempo |

TLS puede terminar en el propio broker o en el proxy ya existente de la VPS. No sumar un proxy nuevo si el instalado cubre WSS/HTTPS; TCP TLS requiere su configuración correspondiente. La persistencia debe vivir fuera de la capa efímera del contenedor. El broker verá metadatos de tráfico aunque los payloads estén cifrados.

## 3. Investigación GitHub para intercambio directo

| Proyecto | Qué aporta | Encaje y limitación |
|---|---|---|
| [flutter-webrtc/flutter-webrtc](https://github.com/flutter-webrtc/flutter-webrtc) | DataChannels Android, Web y escritorio; MIT | Primera opción de prototipo directo multiplataforma. Transporte, sin journal/merge de negocio |
| [localsend/localsend](https://github.com/localsend/localsend) y [protocolo](https://github.com/localsend/protocol) | App Flutter de intercambio LAN por HTTPS; repo actual Apache-2.0 | Referencia de discovery, consentimiento y streaming. Verificar commit/licencias de componentes; no asumir que sigue siendo Dart puro: el árbol actual requiere Rust |
| [mannprerak2/nearby_connections](https://github.com/mannprerak2/nearby_connections) | Plugin Android que transfiere bytes/archivos con Nearby; BSD-2-Clause | Transporte cercano adicional; no sustituye conexiones entre ciudades ni soporte Web |
| [schlagmichdoch/PairDrop](https://github.com/schlagmichdoch/PairDrop) | WebRTC/WebSockets, pairing y envío de archivos; GPL-3.0 | Referencia de UX y señalización. Usa TURN en escenarios NAT: no prueba conectividad universal directa. No copiar código sin revisar licencia |
| [n0-computer/iroh](https://github.com/n0-computer/iroh) | QUIC, identidad por clave, NAT traversal; MIT/Apache-2.0 | Candidato nativo. Puede recurrir a relay; verificar desactivación si se exige directo estricto |
| [snowpinelabs/iroh_dart](https://github.com/snowpinelabs/iroh_dart) | Binding Dart/Flutter de Iroh vía Rust; Apache-2.0 | Android/iOS/escritorio declarados. No asumir Web equivalente ni madurez del core idéntica a la del binding |
| [n0-computer/iroh-docs](https://github.com/n0-computer/iroh-docs) | Sincronización de documentos clave/valor firmados | Solución más completa que sockets, pero adaptar datos relacionales y permisos requiere rediseño |
| [syncthing/syncthing](https://github.com/syncthing/syncthing) | Replicación continua de archivos; MPL-2.0 | Referencia de bloques/reanudación. No sincronizar la SQLite activa; la app Android oficial está [archivada](https://github.com/syncthing/syncthing-android) |
| [cachapa/sqlite_crdt](https://github.com/cachapa/sqlite_crdt) y [sql_crdt](https://github.com/cachapa/sql_crdt) | Cambios/merge SQL y HLC en Dart | Usa sqflite; integración con Drift no es automática; validar semántica y no usar LWW para dinero |
| [vlcn-io/cr-sqlite](https://github.com/vlcn-io/cr-sqlite) | Extensión SQLite para replicación CRDT; MIT | Candidato de laboratorio; exigir pruebas de FK, constraints, migraciones y librería nativa de Drift |
| [automerge/automerge](https://github.com/automerge/automerge) | Estructuras de documento con cambios concurrentes | Útil si el dominio se remodela; no reemplaza validaciones financieras ni se ha validado su binding Flutter aquí |

Ninguno de estos repositorios demuestra por sí mismo que los saldos, compras o asignaciones de Decolumax converjan correctamente. Primero reutilizar transporte; mantener reglas de negocio e historial bajo pruebas del proyecto.

### Señales de mantenimiento verificadas

Consulta adicional a la API pública de GitHub, campo `pushed_at` en UTC. Indica actividad del repo, no calidad ni que exista una versión publicada con esos cambios. Todos estos repositorios devolvieron `archived=false`.

| Repo | Último push informado |
|---|---|
| flutter-webrtc/flutter-webrtc | 2026-09-22 |
| localsend/localsend | 2026-10-06 UTC (2026-10-05 en Lima) |
| mannprerak2/nearby_connections | 2025-02-19 |
| snowpinelabs/iroh_dart | 2026-09-29 |
| schlagmichdoch/PairDrop | 2026-04-22 |
| cachapa/sqlite_crdt | 2026-03-25 |
| vlcn-io/cr-sqlite | 2026-08-10 |
| n0-computer/iroh | 2026-10-05 |

`flutter_webrtc` mostró release `v1.6.2+hotfix.3`; se debe fijar una versión revisada al empezar el prototipo. No instalar automáticamente la rama principal por ser reciente. [Releases](https://github.com/flutter-webrtc/flutter-webrtc/releases).

Nearby usa Bluetooth/BLE/Wi-Fi y su SDK de Google Play services recoge analítica de uso; si se necesita independencia de esos servicios, priorizar LAN/WebRTC. Comparar códigos de autenticación al emparejar. [Descripción oficial](https://developers.google.com/nearby/connections/overview), [autenticación](https://developers.google.com/nearby/connections/android/manage-connections).

WebRTC requiere señalización y negociación ICE; STUN ayuda a descubrir rutas y TURN transporta datos cuando hace falta relay. Para directo estricto omitir TURN y comprobar la ruta elegida; no ocultar un fallback por WebSocket. [Guía oficial](https://webrtc.org/getting-started/peer-connections).

## 4. Optimización después de cerrar funcionalidad

Parámetros iniciales de experimento, sujetos a medición; no garantías de capacidad:

| Área | Punto de partida | Evidencia para ajustarlo |
|---|---|---|
| Broker JetStream | Comparar límites de contenedor 128 y 256 MiB, 0,25–0,5 CPU; una réplica | RSS/pico con TLS, cola acumulada, reconexiones y fsync; cero OOM y errores de entrega |
| Almacenamiento | `file`, cuota de prueba 1 GiB, TTL 7 días, límites por workspace/dispositivo | Crecimiento real de datos+índices, espacio libre, mensajes pendientes y antigüedad |
| Buffers | 1 lote en vuelo inicialmente, 100 operaciones o 256 KiB, lo que ocurra primero | RAM del teléfono y latencia del commit; límites también de tamaño descomprimido |
| Adjuntos | Chunk inicial 64 KiB, streaming y hash; descarga a demanda | RAM casi independiente del tamaño del archivo; reanudación con pocos bytes repetidos |
| Conexiones | Una sesión activa por dispositivo; backoff con jitter 1–60 s | Consumo de batería y recuperación de red; no bucles permanentes en background |
| P2P DataChannel | Mensajes pequeños de 16 KiB ajustados al máximo negociado, cola acotada | `bufferedAmount`, tiempo de ACK, pérdida de red; no leer PDF entero en RAM |
| Base local | Índices workspace/origen/secuencia, transacciones por agregado/lote | `EXPLAIN QUERY PLAN`, ingestión sin bloquear UI; compactación después de checkpoint |
| Compresión | Solo lotes suficientemente grandes y antes del cifrado | Ahorro de bytes frente a CPU; no recomprimir PDFs/imágenes ya comprimidos |

El límite de memoria JetStream configura almacenamiento/buffers concretos; **no** es el límite total RSS del proceso. El límite del contenedor debe tener margen. El uso de `scratch` reduce archivos de imagen, no garantiza menor RAM. No reducir Argon2, comprobaciones de firma ni durabilidad como «optimización» implícita.

Dimensionamiento de cola: bytes cifrados/día × días offline × copias destinadas, más índices/recibos y margen. Ejemplo aritmético: 5.000 operaciones/día × 2 KiB × 7 días ≈ 68 MiB de payload por copia, antes de índices y adjuntos. No es una estimación del tráfico real de Decolumax.

## 5. Benchmark y selección reproducibles

1. Fijar versión/digest de imagen, versión del cliente Dart, plataforma/ABI, límites Docker y hardware; registrar tamaño comprimido y desplegado por separado.
2. Comparar NATS file y Mosquitto persistente usando idénticos paquetes cifrados, 2/4 dispositivos, 1.000/10.000/100.000 operaciones y cola offline. No comparar brokers vacíos con motores llenos.
3. Medir reposo y picos de publicación, recuperación de backlog y reinicio. Conservar CPU, RSS, caché de páginas del host, disco, latencias p50/p95 y red. Incluir TLS y autenticación del despliegue real.
4. Cortar emisor/receptor/broker en los puntos del ACK; diferenciar reinicio normal, kill de proceso y pérdida de energía. Verificar hashes, deduplicación y que ningún mensaje confirmado por la app desaparezca.
5. Comparar DataChannel y, si aporta al uso real, LAN/Nearby con los mismos datos; medir conexión, éxito por red, throughput, batería y aumento de APK. No declarar un transporte «óptimo» usando solo estrellas de GitHub.
6. Android físico con release/profile, varios estados de batería y pantalla. Web con tab suspendida. La política Android puede suspender red/trabajos y limita servicios dataSync en background. [Doze](https://developer.android.com/training/monitoring-device-state/doze-standby), [timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout).
7. Aceptar la opción que preserve operaciones, aislamiento, recuperación y límites bajo los casos representativos. Si 128 MiB falla, evaluar 256 MiB antes de cambiar lenguaje o reescribir un broker.

Resultados pendientes: tamaño exacto de estas imágenes en la VPS, RAM habitual/picos, compatibilidad de ACK/autorización del cliente Dart y consumo móvil. Las mediciones previas de 62 MiB en reposo correspondían a API+PostgreSQL local y no prueban este diseño ni una carga real de sync.
