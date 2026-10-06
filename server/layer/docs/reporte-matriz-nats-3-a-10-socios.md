# Matriz local de carga NATS: 3 a 10 socios

Fecha: 2026-10-05, America/Lima. Se midió NATS JetStream por sí solo, después del [reensayo de recuperación](reporte-prueba-nats-ampliada.md). El broker se ejecutó en `nats:2.15.0-scratch` con volumen local, `GOMEMLIMIT=150MiB`, `max_mem=64M`, `max_file=900M`, `max_buffered_msgs=2000`, `max_buffered_size=32M`, límite Docker de 256 MiB y 0,50 CPU.

## Diseño de la matriz

Se probaron las nueve combinaciones de 3, 5 y 10 socios con 10, 20 y 100 operaciones por socio. Cada combinación se repitió en tres rondas. En cada ronda, cada socio generó ese número de operaciones y envió cada operación a los demás socios (fan-out todos contra todos). Por ejemplo, 10 socios × 100 operaciones generan 1.000 operaciones originales y 9.000 entregas al broker en una ronda.

Cada sobre, de unos 1.878 bytes cifrados en promedio, representa una compra ficticia con dos ítems y movimientos de inventario sintéticos. Los receptores autenticaron/descifraron el sobre, verificaron IDs, escribieron cada ID a un archivo de prueba con `fsync` y enviaron ACK confirmado al servidor. Cada destinatario tenía un consumidor durable propio. Los IDs se verificaron únicos para cada receptor.

## Resultados por perfil

Las columnas de entrega y confirmación abarcan las tres rondas; el tiempo de recepción es la mediana de una ronda e incluye descifrado, `fsync` y ACK confirmado.

| Socios | Operaciones por socio/ronda | Entregas por ronda tras fan-out | Entregas totales en 3 rondas | p95 ACK de publicación | Mediana de recepción + fsync + ACK por ronda | Resultado |
|---:|---:|---:|---:|---:|---:|---|
| 3 | 10 | 60 | 180 | 1,832 ms | 99,841 ms | Pasó |
| 3 | 20 | 120 | 360 | 1,288 ms | 196,542 ms | Pasó |
| 3 | 100 | 600 | 1.800 | 1,225 ms | 962,096 ms | Pasó |
| 5 | 10 | 200 | 600 | 2,220 ms | 307,256 ms | Pasó |
| 5 | 20 | 400 | 1.200 | 1,638 ms | 646,037 ms | Pasó |
| 5 | 100 | 2.000 | 6.000 | 1,487 ms | 3.109,105 ms | Pasó |
| 10 | 10 | 900 | 2.700 | 2,341 ms | 1.481,157 ms | Pasó |
| 10 | 20 | 1.800 | 5.400 | 3,540 ms | 2.901,723 ms | Pasó |
| 10 | 100 | 9.000 | 27.000 | 2,562 ms | 14.111,663 ms | Pasó |

El total fue **45.240 entregas**, todas recibidas, descifradas, fsyncadas y confirmadas, sin IDs duplicados. JetStream reportó 45.240 mensajes y 91.660.686 bytes al final; la diferencia frente a los bytes de payload incluye la representación y metadata internas del stream. Hubo 54 consumidores durables, pues el ensayo conservó consumidores separados para los nueve perfiles.

## Picos de recursos

Se mantuvo `docker stats` transmitiendo durante la matriz, con muestras aproximadamente cada segundo:

- Máximo de memoria observado: **123,2 MiB de 256 MiB**.
- Máximo de CPU observado: **51,12% en la lectura de Docker**, aproximadamente el tope configurado de 0,50 CPU.
- No hubo OOM ni límite de memoria alcanzado.
- El mayor tráfico simultáneo fue el perfil de 10 socios × 100 operaciones: 9.000 entregas por ronda; su ronda de recepción, descifrado, `fsync` y ACK confirmado tuvo mediana de 14,11 s y máximo medido de 16,07 s.

La memoria subió a lo largo de la matriz porque se retuvieron los mensajes de los perfiles anteriores y sus consumidores en el mismo stream. Por tanto, el pico representa la ejecución acumulativa completa, no nueve contenedores reiniciados en estado vacío. Es un muestreo de Docker y puede perder picos más cortos que el intervalo de captura; no equivale a un perfilador de memoria del proceso.

## Lectura para el tamaño inicial

Para este patrón de tres a diez socios, **256 MiB y 0,50 CPU son un punto de inicio razonable para el contenedor NATS aislado**: el máximo observado dejó aproximadamente 133 MiB bajo el límite. El perfil de diez socios con cien operaciones simultáneas ya consumió prácticamente el medio núcleo asignado durante ráfagas y necesitó hasta 16 s para confirmar toda la recepción sintética. Si esperamos más concurrencia, adjuntos o bootstrap inicial grande, habría que probar 1 CPU y más RAM antes de fijar el presupuesto.

Esto no dimensiona la VPS completa: API, PostgreSQL, proxy, sistema y Docker consumen recursos aparte. Tampoco prueba una duración prolongada ni límites de retención llenos; el contenedor de prueba tuvo `max_file=900M` y el stream `max_bytes=400M`, y usó unos 91,7 MB al final. En despliegue, si se alcanza una cuota, debe rechazarse la publicación de forma observable y permitir reintento desde el Outbox; no purgar silenciosamente operaciones todavía no aplicadas.

## Alcance y límites

Los diez socios eran clientes sintéticos dentro de un runner Node 22. Se usó una clave AES-GCM de laboratorio, una credencial NATS compartida, un único broker y archivos `fsync` como sink local; no fueron dispositivos Flutter/Drift ni se probó aislamiento de permisos por organización, TLS, API/DB, adjuntos reales, backup/restauración de VPS o conectividad móvil. La medición valida carga y costo del broker para estos mensajes, pero no reemplaza la prueba de extremo a extremo de la aplicación.
