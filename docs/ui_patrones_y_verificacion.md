# Patrones de UI y verificación visual

Fecha: 2026-10-05. Entrega: navegación adaptable, componentes compartidos e iconografía transparente.

## Implementado

| Componente / patrón | Responsabilidad y uso |
| --- | --- |
| `AppDestination` | Catálogo único de destinos: etiqueta completa, etiqueta compacta, icono y acento. Barra inferior, rail y pantallas consumen el mismo catálogo. |
| `NavigateToIntent` + `Actions` | Una pantalla expresa la intención de navegar a un destino; `HomeScreen` resuelve la selección. Los accesos del dashboard ya no dependen de índices numéricos. |
| `AppNavigationShell` | Presentación de barra inferior o rail. Conserva el mismo subárbol de contenido al cambiar de tamaño; no recrea formularios para animarlos. |
| `IndexedStack` + `TickerMode` | Conserva el estado de las pestañas y pausa sus animaciones cuando no están visibles. Esto no cancela sus suscripciones a datos. |
| `AppPageTitle` | Título con icono o marca, semántica de encabezado y elipsis. Usado en las cinco pantallas principales. El texto completo permanece disponible en el tooltip. |
| `AppSectionHeader` | Jerarquía compartida en Inicio y Más. Las acciones pasan debajo del título en espacios estrechos o con texto ampliado. |
| `AppNavigationTile` | Acceso reutilizable a módulos en Más: icono transparente, título, descripción que puede ocupar varias líneas y acción accesible. |
| `AppBrandMark` | SVG sin rectángulo de fondo, reutilizado en Inicio móvil y en el rail. |
| `AppMotion` | Duración de 220 ms y curva común; las transiciones propias y la barra móvil respetan `disableAnimations`. |

La barra tiene superficie redondeada, borde discreto y selección con fondo tenue. Los iconos Lucide son vectoriales sin fondo; el acento complementa la etiqueta y el indicador de selección. Se conservan los cinco destinos y sus módulos. En ventanas bajas se usa barra inferior para evitar que el rail desborde. La barra ocupa espacio en el layout y respeta el área segura, de modo que no tapa el final del contenido.

No se añadieron paquetes. La tipografía y los colores de navegación se definen en `AppTheme`; se preserva el tema oscuro existente. La transparencia corresponde al SVG y a los iconos, no a eliminar la superficie legible de la navegación.

Ejemplo de acción desde una pantalla bajo `HomeScreen`:

```dart
Actions.invoke(context, const NavigateToIntent(AppDestination.projects));
```

Los accesos a subpantallas siguen usando `Navigator.push`; esta entrega centraliza los destinos principales. Nuevos módulos deben reutilizar estos componentes antes de crear variantes locales. Las acciones de crear, guardar y reintentar necesitan sus contratos propios al integrar cada flujo; no se introdujo un bus de eventos global.

## Evidencia

Comando ejecutado en `apps/client`:

```text
flutter test --no-pub test/app_navigation_shell_test.dart test/navigation_responsive_test.dart tool/render_ui_preview.dart --update-goldens
```

Resultado: **20 pruebas pasan** (16 de navegación/componentes y 4 de renderizado). Cubren navegación por intención desde Inicio, conservación de un formulario al cambiar de pestaña y de breakpoint, objetivos de navegación de al menos 48 px, ventanas bajas, texto ampliado y reducción de movimiento.

`flutter analyze --no-pub`: sin incidencias. El APK generado contiene el SVG actualizado sin rectángulo de fondo; se comprobó el asset dentro del archivo compilado.

Capturas generadas en `apps/client/build/ui-review/` y revisadas visualmente:

| Captura | Dimensiones | Escala de texto | Resultado |
| --- | --- | --- | --- |
| `mobile.png` | 390 × 844 | 1,0 | Barra inferior y menú legibles. |
| `small-large-text.png` | 320 × 740 | 1,6 | Descripciones multilínea; título sin desbordamiento. La etiqueta Finanzas usa elipsis en este ancho; el tooltip conserva el nombre completo. |
| `tablet.png` | 1024 × 800 | 1,0 | Rail con marca transparente y menú en columnas. |
| `landscape.png` | 844 × 390 | 1,0 | Barra inferior en ventana baja y contenido desplazable. |

La revisión inicial encontró un desbordamiento de 35 px en el título de Más con texto ampliado: se corrigió usando `AppPageTitle`. El generador carga las fuentes del SDK y los iconos del manifiesto para evitar los cuadrados de la fuente de prueba Ahem. Las capturas muestran el menú y el contenedor reales, sin datos de negocio; no sustituyen una prueba del APK en teléfono. El generador está en `apps/client/tool/render_ui_preview.dart` y los PNG son artefactos regenerables, fuera de Git.

La compilación `flutter build apk --debug --no-pub --dart-define=BUILD_DATE=2026-10-05 --dart-define=BUILD_MODE=debug` terminó correctamente: `apps/client/build/app/outputs/flutter-apk/app-debug.apk`, 195.052.623 bytes. Se compiló el árbol de trabajo, que también contiene cambios previos de dependencias y de Versión e instalación. Esos cambios se conservan fuera del commit de esta entrega; las capturas de tablet incluyen dicha opción previa.

## Pendientes independientes

1. **P0 — Dashboard:** corregir la consulta SQL de herramientas que falló en la auditoría, mostrar carga/error reales y sustituir el refresco simulado. Esta entrega visual conserva la lógica de datos existente; las 20 pruebas anteriores no son la suite completa de negocio.
2. **P1 — Conexión y socios:** configuración segura, diagnóstico real de TLS/autenticación/permisos/JetStream, organización activa, miembros aceptados y dispositivos autorizados.
3. **P1 — Sincronización:** integrar outbox/inbox, cifrado, reintentos, recibos y conflictos. Las futuras vistas deben distinguir guardado local, recepción por el buzón y aplicación por cada destinatario.
4. **P2 — Extensión del sistema visual:** aplicar encabezados, estados y acciones compartidas a ajustes, fichas y formularios; validar teclado, foco, nombres largos y lectores de pantalla en dispositivos reales. La preferencia de tema claro/sistema todavía no se aplica.
5. **P2 — Identidad y distribución:** unificar nombre de aplicación/launcher/versión, icono adaptativo Android y firma de release. Este SVG de interfaz no cambia automáticamente el icono del launcher.

La guía describe el estado entregado y sus límites. No acredita conectividad NATS de producción, autorización de socios ni despliegue en VPS.
