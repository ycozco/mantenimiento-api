# Reporte de prueba local: buzones cifrados

Fecha de ejecución: 2026-10-05, hora local America/Lima. La prueba corrió NATS JetStream y Eclipse Mosquitto al mismo tiempo en Docker Desktop, con diez clientes sintéticos por protocolo. El objetivo fue medir una carga modesta de sincronización y observar qué sucede con mensajes destinados a un dispositivo desconectado.

## Resultado medido

| Métrica | NATS JetStream | Mosquitto MQTT |
|---|---:|---:|
| Clientes simultáneos | 10 | 10 |
| Publicaciones online | 5.000 | 5.000 |
| Bytes de sobres cifrados publicados | 5.836.040 (~1.167 bytes/mensaje) | 5.836.040 (~1.167 bytes/mensaje) |
| Conexión inicial de diez clientes | 18 ms | 123 ms |
| Tiempo de publicación con ACK del broker | 785 ms | 13.290 ms |
| Latencia individual de ACK p50 / p95 / máxima | 1,285 / 2,837 / 10,670 ms | 23,006 / 46,548 / 84,523 ms |
| Entrega, descifrado y fsync online | 10.567 ms | 13.290 ms hasta el último receptor |
| Mensajes recibidos por dispositivo | 500 cada uno | 500 cada uno |
| Publicación de 100 mensajes para el dispositivo offline | 65 ms | 154 ms |
| Tiempo de ejecución del escenario online | 11.490 ms | 14.921 ms |

Los ACK de MQTT se midieron por `publish()` QoS 1. NATS utilizó JetStream file storage y ACK de publicación. Las latencias son las de esta corrida, no un SLA: ambos procesos compartieron el mismo host y se ejecutaron en paralelo. La tasa de pared resultante fue aproximadamente 435 mensajes/s en NATS y 335 mensajes/s en MQTT, incluyendo el trabajo sintético del ejecutor.

### Reinicio con destinatario desconectado

La comprobación de recuperación **no pasó como prueba concluyente**:

- NATS guardó el stream en volumen, pero el ejecutor pudo fsync y contar solo 48 de los 100 mensajes solicitados al reconectar `device-05`; el ensayo terminó con `48/100` y no debe interpretarse como entrega completa. La implementación de prueba usó un fetch con expiración y requiere una repetición controlada por lotes antes de decidir sobre la garantía de recuperación.
- Mosquitto restauró la sesión de `device-05` (`sessionPresent=true`). El contador del proceso de recuperación se quedó esperando y una comprobación posterior no encontró mensajes pendientes; como el primer proceso pudo consumir mensajes sin reportar su resultado de forma válida, la entrega de los 100 tampoco se considera demostrada.

Por tanto, la prueba confirma la carga online de ambos servicios, pero no demuestra todavía el requisito crítico de “desconectarse, reiniciar el broker y recuperar todos los mensajes”. No se debe habilitar sincronización de datos reales con base únicamente en este resultado.

## Datos sintéticos y tratamiento

Cada sobre contenía una operación `purchase.recorded` ficticia de un workspace sintético: proveedor “Proveedor ficticio Norte”, factura ficticia en PEN por S/ 1.275, dos artículos y dos IDs de movimiento de inventario. El ejecutor cifró el JSON con AES-256-GCM y validó su descifrado en el receptor. La clave era fija para esta prueba, vivía solo en la memoria del proceso y **no representa** un protocolo seguro de administración de claves. El runner fsyncó IDs de operación a un archivo temporal local como sustituto del commit a Drift; no se utilizó la base de datos ni código Flutter del producto.

El cliente MQTT tuvo credenciales y ACL por dispositivo, limitadas a publicar al siguiente destinatario y leer su propia bandeja. En NATS todos los clientes sintéticos usaron una credencial compartida; no se midió aislamiento de permisos equivalente. La comparación de rendimiento no es una auditoría de seguridad ni una comparación de controles equivalentes.

## Entorno y recursos observados

- Docker Engine Linux en Docker Desktop: 4 CPU y 6.215.159.808 bytes de RAM visibles para el motor.
- Límites idénticos para cada broker: 0,50 CPU y 256 MiB.
- Imágenes: `nats:2.15.0-scratch` (7.281.536 bytes) y `eclipse-mosquitto:2.1.2-alpine` (12.983.433 bytes).
- Snapshot posterior a la prueba (no pico durante carga): NATS 12,04 MiB RAM y 0,18% CPU; Mosquitto 2,781 MiB RAM y 0,03% CPU.
- Persistencia en volúmenes Docker separados. Los tamaños reportados son de la imagen comprimida local según Docker; no incluyen datos/volúmenes ni el runner.

El snapshot de CPU/RAM es posterior a la carga y no permite afirmar el consumo máximo. Los topes configurados son límites, no consumo esperado de producción. Una VPS de 384 MiB no se valida aquí: el ejecutor, sistema base, proxy/TLS, margen de picos, almacenamiento y monitoreo también deben entrar en el presupuesto.

## Alcance y repetición requerida

La prueba usó un único proceso Node 22 en contenedor para simular diez clientes; no fueron diez teléfonos, redes móviles, instalaciones Flutter, Drift ni sesiones reales de workspace. No midió batería, uso prolongado, pérdida de paquetes WAN, disco lleno, TLS, cuotas, recuperación de snapshots ni concurrencia superior a diez clientes. Las carpetas, credenciales y datos usados fueron temporales y ficticios.

Antes de seleccionar el transporte, repetir el ensayo de cola offline desde estado limpio para cada servicio: publicar exactamente 100 mensajes dirigidos al cliente desconectado; confirmar el ACK durable; detener el broker de forma abrupta y reiniciarlo; reconectar con identidad/sesión persistente; consumir por lotes hasta 100; validar IDs únicos y contenido autenticado; fsync local antes del ACK; y verificar cero pendientes y cero duplicados. Añadir captura del estado del broker y del sink por fase. Después probar en dos dispositivos Flutter reales, incluyendo Android en segundo plano y reconexión por red móvil.

Conclusión provisional: en esta corrida NATS tuvo menos latencia de publicación y menor tiempo total que MQTT bajo carga simultánea. Debido a la recuperación offline no concluyente, esto solo orienta el siguiente prototipo; no cierra la selección técnica.
