# Reensayo ampliado de NATS JetStream

Fecha: 2026-10-05, America/Lima. Este reensayo amplía y corrige la evidencia del [ensayo comparativo anterior](reporte-prueba-local-buzones.md), concentrándose solo en NATS JetStream. Los datos son sintéticos; no se conectó la aplicación Flutter ni una base Drift de producción.

La matriz posterior con hasta diez socios y picos de CPU/RAM está en [reporte-matriz-nats-3-a-10-socios.md](reporte-matriz-nats-3-a-10-socios.md).

## Escenario

- `nats:2.15.0-scratch`, JetStream con almacenamiento `file`, volumen Docker persistente y límites del contenedor de 0,50 CPU y 256 MiB.
- Un proceso runner Node 22 abrió diez conexiones NATS separadas, una por cliente simulado. Los diez clientes publicaron en paralelo 1.000 operaciones cada uno (10.000 en línea).
- Sobres JSON ficticios de compra e inventario cifrados con AES-256-GCM; tamaño medio medido: 1.889 bytes. Cada receptor verificó el tag GCM y los campos de negocio, fsyncó el ID de operación y solo entonces envió `ackAck()` para que el servidor confirmara el ACK.
- La operación de ejemplo representa una compra ficticia de S/ 1.275, con proveedor e ítems sintéticos. La clave fija solo existió en memoria del runner.
- El consumidor `device-05` quedó sin lecturas mientras se publicaron 100 mensajes adicionales a su bandeja. Después se terminó el proceso del broker con SIGKILL y se volvió a iniciar conservando el volumen. El consumidor volvió a conectarse y recuperó esos mensajes.
- En una prueba separada se fsyncó una operación local y se interrumpió el cliente antes del ACK. NATS la volvió a entregar; el sink de prueba aplicó el ID de forma idempotente antes de confirmar el ACK.

## Resultados

| Medición | Resultado |
|---|---:|
| Conexión de diez clientes | 14,409 ms |
| Mensajes online publicados con ACK | 10.000 |
| Tiempo de publicación y tasa de ACK | 2.657,069 ms; 3.763,55 mensajes/s |
| Latencia individual de ACK de publicación p50 / p95 / máximo | 1,970 / 5,111 / 29,556 ms |
| Sobres publicados online | 18.890.000 bytes aprox. (1.889 bytes de promedio por sobre) |
| Aplicación online: validación, descifrado, fsync y ACK confirmado | 10.000/10.000; 16.070,533 ms agregados |
| Resultado por cliente receptor | 1.000 IDs únicos de 1.000 esperados para cada uno de los diez |
| Mensajes offline confirmados al publicarse | 100/100; publicación en 35,805 ms |
| Tras SIGKILL y reinicio | 100 pendientes antes; 100 IDs únicos recuperados; 0 pendientes y 0 ACK pendientes después |
| Tiempo de recuperación local, descifrado, fsync y ACK confirmado | 182,443 ms para 100 mensajes |
| Corte después del fsync local y antes del ACK | Redelivery del mismo ID, entrega número 2; una sola operación única en el sink; 0 pendientes tras ACK |
| JetStream al final del ensayo | 10.101 mensajes, 19.985.060 bytes, 11 consumidores (incluye el consumidor de prueba de redelivery) |

La tasa de publicación mide confirmaciones del broker. El tiempo de 16,071 s incluye la etapa de descarga concurrente, descifrado, fsync local de cada ID y ACK confirmado; equivale a unas 622 operaciones/s de extremo a extremo para este runner. No es la velocidad de una importación Drift ni una promesa para teléfonos reales.

## Recursos observados

- Límite del contenedor: 0,50 CPU y 256 MiB.
- Una captura posterior al ensayo mostró 19,11 MiB de RAM y 0,20% CPU. Es una muestra posterior, **no el pico** durante carga.
- El almacenamiento reportado por JetStream al final fue 19.985.060 bytes para el stream y sus mensajes; el volumen temporal se eliminó al cerrar el ensayo.
- La imagen usada fue `nats:2.15.0-scratch`; el tamaño local observado para la imagen fue 7.281.536 bytes. No incluye datos persistidos, runner ni espacio del sistema Docker.

## Interpretación

En este reensayo NATS pasó los criterios locales de carga online, persistencia de 100 mensajes durante un SIGKILL del broker y redelivery después de un corte entre commit local y ACK. La observación anterior de 48/100 queda superada por este ensayo aislado y controlado; no se pudo atribuir retrospectivamente aquel conteo a una causa única, así que se conserva en el informe histórico.

El ensayo verifica primitivas del broker junto con un sink de archivos fsync. No verifica almacenamiento Drift, gestión/revocación de claves, permisos por socio, aislamiento multi-tenant, TLS, cuota llena, duración de varios días, consumo pico, Android en segundo plano ni una VPS de 384 MiB. La clave fija y la credencial compartida son solo de laboratorio. La entrega durable del broker tampoco sustituye la validación, deduplicación y conciliación del protocolo de Decolumax. JetStream documenta entrega al menos una vez para consumidores con ACK; por eso la prueba incluye explícitamente redelivery y aplicación idempotente ([semántica de consumidores JetStream](https://docs.nats.io/nats-concepts/jetstream/consumers)).

El siguiente paso de validación es repetir el contrato del mismo cliente Flutter/Drift en dos dispositivos físicos, con clave por dispositivo, TLS, persistencia en una transacción Drift y ACK posterior al commit real. Antes de dimensionar VPS se debe registrar pico de RSS/CPU y crecimiento de disco durante una sesión móvil prolongada, con margen para API, proxy y sistema operativo.
