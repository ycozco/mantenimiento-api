# Cliente Flutter y relay de sincronización

El cliente no conecta al puerto NATS ni contiene sus credenciales. El flujo es:

```text
Flutter --HTTPS/JWT--> API Decolumax --TLS/runtime user--> NATS JetStream
```

PostgreSQL conserva identidad y sesiones. El payload del buzón se conserva en el stream `DECO_SYNC`; la API únicamente publica sobres cifrados y entrega los sobres del workspace del JWT.

## Variables de API

Configurar en el `.env` del servidor, nunca en Flutter:

```env
NATS_URL=tls://mant.qpsecure.cloud:4422
NATS_SYNC_USER=<usuario runtime de la API>
NATS_SYNC_PASSWORD=<clave runtime de la API>
NATS_SYNC_STREAM=DECO_SYNC
CORS_ORIGINS=https://<origen-web-de-la-app>
```

El usuario NATS debe poder publicar en `deco.>` y usar las APIs JetStream requeridas para consultar el stream. No usar el usuario administrativo ni credenciales de aplicación móvil. El puerto `4422` es únicamente la conexión privada API-servidor NATS sobre TLS. El cliente Flutter consume HTTPS del API.

Para NPM, enrutar el host HTTPS reservado para el API al servicio `api:3000` dentro de la red del proxy. El servicio no debe exponer públicamente el puerto 3000 ni cambiar el stream TCP que ya usa `mant.qpsecure.cloud:4422`. La API queda enlazada a `127.0.0.1:3000` en el host, como está en `deploy/compose.production.yml`.

## Rutas disponibles

| Método y ruta | Autorización | Función |
|---|---|---|
| `POST /api/v1/auth/login` | Credenciales de cuenta | Emite access y refresh token asociado al dispositivo |
| `POST /api/v1/auth/refresh` | Refresh token | Rota los tokens |
| `POST /api/v1/auth/logout` | Refresh token | Revoca la sesión |
| `POST /api/v1/sync/push` | Bearer JWT | Publica un sobre cifrado en `deco.<workspaceId>.<entityType>` |
| `GET /api/v1/sync/pull?cursor=0&limit=50` | Bearer JWT | Lee sobres del workspace y devuelve cursor global |

`push` requiere `operationId` UUID, `entityType`, `entityId` UUID, `schemaVersion`, `nonce` y `ciphertext` en Base64. `operationId` es el ID de deduplicación de JetStream. La API toma `workspaceId`, `actorId` y `deviceId` de la sesión, no del cuerpo. Cuerpo cifrado máximo: 70.000 caracteres; el stream mantiene además su límite configurado de payload.

El cliente guarda cada página en `sync_inbox` y el cursor en `app_metadata` en una transacción Drift antes de solicitar la siguiente. Así un cierre entre descarga y persistencia no avanza el cursor por delante de los datos guardados.

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
flutter build apk --dart-define=SYNC_API_BASE_URL=https://<dominio-api>/api/v1
flutter build web --dart-define=SYNC_API_BASE_URL=https://<dominio-api>/api/v1
```

Web requiere que `CORS_ORIGINS` contenga el origen desde donde se sirve la app. El DNS `mant.qpsecure.cloud` descrito para NATS TCP no crea por sí mismo un endpoint HTTP para la API.

## Límites actuales

- Flutter inicia sesión, descarga y almacena sobres cifrados; aún no publica cambios locales.
- La app aún no implementa acuerdo/rotación de claves entre socios. No se debe colocar texto claro en `ciphertext` para probar el buzón.
- La app aún no descifra ni aplica sobres a las tablas de negocio. “Guardado” significa almacenado en el inbox del dispositivo, no aplicado por otro socio.
- La lista de usuarios del mismo workspace es hoy la frontera de lectura. Invitación aceptada, concesiones por dispositivo, revocación por dispositivo y permisos por socio están pendientes.
- `pull` usa el cursor de secuencia global del stream y consulta secuencias una por una; filtra cada sobre por `workspaceId` en el backend. Está acotado a 2.000 secuencias por llamada. Se debe reemplazar por consumers JetStream aislados por workspace/dispositivo antes de crecer el volumen o habilitar múltiples organizaciones.
- El backend no se ha probado en este entorno contra el VPS desplegado. El proceso sigue siendo local hasta configurar el dominio HTTP, variables, NPM y desplegar la nueva imagen.
