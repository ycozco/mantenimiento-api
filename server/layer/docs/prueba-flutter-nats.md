# Adaptador Flutter de prueba para NATS JetStream

Fecha: 2026-10-05. Este paso adapta el cliente Flutter al transporte JetStream medido y añade una prueba contra un contenedor local con los mismos valores base previstos para el VPS. **Es una prueba de transporte, no sincronización de los datos de negocio.**

## Qué se agregó

- Dependencia fijada en `dart_nats 1.4.0`. El paquete declara soporte Android y TLS. Sus interfaces JetStream están marcadas experimentales; se fija la versión para poder repetir el ensayo y revisar cambios antes de actualizar. [Paquete y documentación](https://pub.dev/packages/dart_nats).
- Permiso `INTERNET` en Android.
- Configuración NATS en `server/layer/deploy/nats/nats.conf`: TLS, usuario/contraseña de laboratorio, JetStream en archivos, `sync_interval: "always"`, 64 MB para memoria y 900 MB para archivos.
- Compose aislado de prueba: NATS `2.15.0-scratch`, cuota de 256 MiB, CPU 0,50, 32 conexiones, monitor ligado a loopback y volumen con persistencia. Publica 4222/8222 solo en `127.0.0.1`.
- Cliente de ensayo Dart en `apps/client/tool/nats_mailbox_smoke.dart` y lanzador Windows en `apps/client/tool/run_nats_mailbox_smoke.ps1`. El lanzador crea certificado local, espera a que NATS esté listo, ejecuta el cliente y detiene el servicio al pasar `-StopAfter`.

El ensayo crea/actualiza un stream de archivo `SYNC_SMOKE` con límite de 400 MB y retención de siete días; crea un consumidor durable, publica una carga sintética aleatoria, repite el mismo `Nats-Msg-Id`, recupera la única copia y espera confirmación del ACK. No se usa información empresarial.

## Repetir el ensayo en Windows

Desde la raíz del repositorio, con Docker Desktop y Git for Windows/OpenSSL instalados:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File apps/client/tool/run_nats_mailbox_smoke.ps1 -StopAfter
```

Sin `-StopAfter`, NATS queda iniciado para que otra instancia Flutter pueda conectarse. El contenedor se detiene al usar `-StopAfter`; el volumen con datos sintéticos se conserva entre ejecuciones. Los certificados de laboratorio quedan en `%TEMP%\decolumax-nats-smoke-certs`.

La prueba usa `tls://localhost:4222`, valida el certificado local y autentica con `sync_smoke`. Esa credencial está limitada al ensayo enlazado a loopback y no debe reutilizarse en el VPS. En el VPS, la app debe usar un certificado público válido y credenciales individuales con permisos acotados.

## Resultado de ejecución

Ejecutado localmente contra el contenedor Docker, no contra el VPS:

```text
PASS stream=SYNC_SMOKE storedMessages=2 publishSequence=2 duplicate=true received=1 ack=confirmed tls=true storage=file
```

El stream ya contenía el mensaje sintético de la primera ejecución; el segundo intento agregó uno. En ambos casos la segunda publicación con el mismo ID fue reconocida como duplicada y el consumidor recibió una sola copia para el intento actual.

`flutter analyze --no-pub`: sin incidencias. `flutter pub get`: correcto. `flutter build apk --debug`: correcto; se verificó `INTERNET` en el manifest Android fusionado. El APK de depuración resultante mide aproximadamente 194 MB; no es una versión para distribuir.

## Lo que todavía no prueba

- El paquete `dart_nats` declara JetStream experimental; hace falta mantener este smoke de compatibilidad al actualizar.
- La app aún no llama a este transporte desde `SyncQueueRepository`, no tiene una vista de estado NATS y no envía operaciones de Drift.
- No se implementaron cifrado de extremo a extremo, aceptación de socios, gestión segura de claves, ACL por dispositivo, aislamiento de workspace, lógica Inbox/idempotente de aplicación ni conflictos.
- El usuario local tiene permisos amplios de laboratorio. No representa la política de permisos de producción.
- No se probó pérdida de energía del VPS, conectividad móvil real, revocación, expiración de mensajes ni restauración de volumen. El ACK de este ensayo no demuestra por sí solo recuperación ante pérdida física del host.

## Siguiente paso

Integrar el cliente detrás de una interfaz de transporte, generar/leer `deviceId` estable, y conectar un comando sintético desde una acción temporal de diagnóstico dentro de la app. Después implementar el diario de operaciones cifradas y su Inbox transaccional. Solo entonces cambiar la acción temporal por envíos del outbox real. Mantener la API y PostgreSQL sin cambios hasta migrar de forma explícita su función de control de identidades.
