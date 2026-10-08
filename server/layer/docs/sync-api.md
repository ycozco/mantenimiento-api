# Cliente Flutter y relay de sincronizaciÃ³n

El cliente no conecta al puerto NATS ni contiene sus credenciales. El flujo es:

```text
Flutter --HTTPS/JWT--> API Decolumax --TLS/runtime user--> NATS JetStream
```

PostgreSQL conserva identidad y sesiones. El payload del buzÃ³n se conserva en el stream `DECO_SYNC`; la API Ãºnicamente publica sobres cifrados y entrega los sobres del workspace del JWT.

## Variables de API

Configurar en el `.env` del servidor, nunca en Flutter:

```env
NATS_URL=tls://mant.qpsecure.cloud:4422
NATS_SYNC_USER=<usuario runtime de la API>
NATS_SYNC_PASSWORD=<clave runtime de la API>
NATS_SYNC_STREAM=DECO_SYNC
CORS_ORIGINS=https://<origen-web-de-la-app>
```

El usuario NATS debe poder publicar en `deco.>` y usar las APIs JetStream requeridas para consultar el stream. No usar el usuario administrativo ni credenciales de aplicaciÃ³n mÃ³vil. El puerto `4422` es Ãºnicamente la conexiÃ³n privada API-servidor NATS sobre TLS. El cliente Flutter consume HTTPS del API.

Para NPM, crear un Proxy Host para `mant.qpsecure.cloud`, con esquema HTTP, nombre de destino `decolumax-sync-api` y puerto `3000`; activar TLS/Let's Encrypt y redirecciÃ³n HTTPS en NPM. HTTP API entra por 443 y el stream TCP NATS sigue en 4422 sobre el mismo hostname. El API solo se expone dentro de la red Docker `main_npm_network`, sin publicar el puerto 3000 en el host.

## Rutas disponibles

| MÃ©todo y ruta | AutorizaciÃ³n | FunciÃ³n |
|---|---|---|
| `POST /api/v1/auth/login` | Credenciales de cuenta | Emite access y refresh token asociado al dispositivo |
| `POST /api/v1/auth/refresh` | Refresh token | Rota los tokens |
| `POST /api/v1/auth/logout` | Refresh token | Revoca la sesiÃ³n |
| `POST /api/v1/auth/switch-workspace` | Bearer JWT | Revoca la sesiÃ³n actual y emite una sesiÃ³n limitada a otra organizaciÃ³n de la misma identidad |
| `GET /api/v1/organizations` | Bearer JWT | Lista organizaciones activas donde la identidad tiene membresÃ­a |
| `POST /api/v1/organizations` | Bearer JWT | Crea una organizaciÃ³n y asigna al creador rol `owner` |
| `GET /api/v1/organizations/current` | Bearer JWT | Devuelve organizaciÃ³n y rol activos |
| `PATCH /api/v1/organizations/current` | Bearer JWT + `owner`/`admin` | Actualiza nombre o slug de la organizaciÃ³n activa |
| `POST /api/v1/sync/push` | Bearer JWT | Publica un sobre cifrado en `deco.<workspaceId>.<entityType>` |
| `GET /api/v1/sync/pull?cursor=0&limit=50` | Bearer JWT | Lee sobres del workspace y devuelve cursor global |

`push` requiere `operationId` UUID, `entityType`, `entityId` UUID, `schemaVersion`, `nonce` y `ciphertext` en Base64. `operationId` es el ID de deduplicaciÃ³n de JetStream. La API toma `workspaceId`, `actorId` y `deviceId` de la sesiÃ³n, no del cuerpo. Cuerpo cifrado mÃ¡ximo: 70.000 caracteres; el stream mantiene ademÃ¡s su lÃ­mite configurado de payload.

El cliente guarda cada pÃ¡gina en `sync_inbox` y el cursor en `app_metadata` en una transacciÃ³n Drift antes de solicitar la siguiente. AsÃ­ un cierre entre descarga y persistencia no avanza el cursor por delante de los datos guardados.

## Prueba local

En backend:

```powershell
Copy-Item .env.example .env
# Completar DB, claves JWT, NATS runtime y CORS_ORIGINS para desarrollo
npm install
npm run build
npm run start:dev
```

En Flutter, Android Emulator usa `http://10.0.2.2:3000/api/v1` y Web usa `http://localhost:3000/api/v1` por defecto. Para compilar contra el dominio HTTPS del API:

```powershell
flutter build apk --dart-define=SYNC_API_BASE_URL=https://mant.qpsecure.cloud/api/v1
flutter build web --dart-define=SYNC_API_BASE_URL=https://mant.qpsecure.cloud/api/v1
```

Web requiere que `CORS_ORIGINS` contenga el origen desde donde se sirve la app. La ruta HTTP depende de crear el Proxy Host de NPM descrito arriba; el registro DNS existente por sÃ­ solo no configura esa ruta.

## LÃ­mites actuales

- Flutter inicia sesiÃ³n, descarga y almacena sobres cifrados; aÃºn no publica cambios locales.
- La app aÃºn no implementa acuerdo/rotaciÃ³n de claves entre socios. No se debe colocar texto claro en `ciphertext` para probar el buzÃ³n.
- La app aÃºn no descifra ni aplica sobres a las tablas de negocio. â€œGuardadoâ€ significa almacenado en el inbox del dispositivo, no aplicado por otro socio.
- La lista de usuarios del mismo workspace es hoy la frontera de lectura. InvitaciÃ³n aceptada, concesiones por dispositivo, revocaciÃ³n por dispositivo y permisos por socio estÃ¡n pendientes.
- La rama local aÃ±ade la migraciÃ³n `005_global_user_identities.sql` para permitir una identidad de correo en varios workspaces. Debe revisarse/aplicarse con backup en el despliegue; aborta si encuentra correos duplicados con hashes de contraseÃ±a distintos. Los endpoints de organizaciones y cambio de contexto todavÃ­a no estÃ¡n desplegados.
- `pull` usa el cursor de secuencia global del stream y consulta secuencias una por una; filtra cada sobre por `workspaceId` en el backend. EstÃ¡ acotado a 2.000 secuencias por llamada. Se debe reemplazar por consumers JetStream aislados por workspace/dispositivo antes de crecer el volumen o habilitar mÃºltiples organizaciones.
- El backend no se ha probado en este entorno contra el VPS desplegado. El proceso sigue siendo local hasta configurar el dominio HTTP, variables, NPM y desplegar la nueva imagen.

## Cambios de seguridad en desarrollo (no desplegados)

La rama local incorpora limitaciÃ³n persistente de login, refresh y logout; validaciÃ³n de sesiÃ³n activa por peticiÃ³n protegida; validaciÃ³n del secreto al cerrar sesiÃ³n/rotar refresh; y auditorÃ­a de accesos autenticados, fallidos y limitados con IP anonimizada. Las migraciones `003_auth_rate_limit_buckets.sql` y `004_auth_audit_events.sql` deben ejecutarse en el despliegue mediante el flujo normal de migraciones. Estos cambios todavÃ­a no forman parte de la API que responde en el VPS; no comunicar que estas protecciones estÃ¡n activas en producciÃ³n hasta desplegar y verificar esa versiÃ³n.

