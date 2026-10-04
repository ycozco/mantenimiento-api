# 🎨 Diseño de Experiencia de Usuario y UI (V2)
## Decolumax / Mobile Field Operations & Web Administration

---

## 1. Sitemap y Arquitectura de Información

```
                                  [DECOLUMAX SYSTEM]
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
         [MOBILE FIELD APP]                              [WEB ADMIN PORTAL]
                  │                                               │
     ┌────────────┼────────────┐                 ┌────────────────┼────────────────┐
     ▼            ▼            ▼                 ▼                ▼                ▼
[1. Hoy /]   [2. Obras /]  [3. Más /]      [Dashboard & KPI]  [Obras & Proyectos] [CMMS / Servs]
[ Agenda ]   [Proyectos ]  [ Operac ]            │                │                │
     │            │            │           [Inventario &]     [Finanzas &]    [Trabajadores &]
     ▼            ▼            ▼           [Herramientas]     [Balances  ]    [Clientes/Provs]
[+ Quick FAB] [Ficha Obra] [Inventario]          │                │                │
(Gasto/Jornal [Costeo Vivo][Herramientas]  [Calendario]       [Reportes PDF]  [Ajustes & Sync]
 /Consumo/Visita)          [Finanzas]
```

---

## 2. Wireframes ASCII: Experiencia Móvil de Campo (Mobile Field UX)

### 2.1 Pantalla Principal: "Hoy & Agenda de Campo" (Inicio)

```
┌────────────────────────────────────────────────────────┐
│ ☰  DECOLUMAX                    🔔 [2]  👤 Yoset (S1) │
├────────────────────────────────────────────────────────┤
│ 🌤️ Hoy: Sábado, 04 Oct 2026                            │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ⚡ RESUMEN DE HOY:                                  │ │
│ │  • 2 Mantenimientos programados                     │ │
│ │  • 1 Obra activa (Torre B - Red Hidráulica)         │ │
│ │  • 4 Jornaleros en campo                            │ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
│ 📌 SERVICIOS Y MANTENIMIENTOS HOY:                     │
│ ┌────────────────────────────────────────────────────┐ │
│ │ 🚨 ¡HOY! 09:00 AM  • Residencial Los Álamos         │ │
│ │ 🛠️ Mantenimiento Bombas de Agua y Filtros          │ │
│ │ 📍 Av. Principal #450 (Cayma)                       │ │
│ │ 👷 Encargados: Yoset, Carlos                        │ │
│ │ [ 📞 Llamar ]   [ 📍 Mapa ]   [ ✅ Iniciar / Ver ]   │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ⏳ EN 3 DÍAS • Clínica San Marcos                  │ │
│ │ 🌿 Poda de Cerco y Fertilización Césped            │ │
│ │ 📍 Calle Médicos 12 (Yanahuara)                     │ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
│ 🏗️ OBRAS ACTIVAS:                                     │
│ ┌────────────────────────────────────────────────────┐ │
│ │ 🏢 Res. Los Álamos - Torre B                         │ │
│ │ Presupuesto: S/ 45,000 │ Invertido: S/ 14,250 (31%) │ │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
│ │ [ + Jornal ]   [ + Material ]   [ + Gasto Directo ] │ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
│                        ┌───────────┐                   │
│                        │  (+) FAB  │                   │
│                        └───────────┘                   │
├────────────────────────────────────────────────────────┤
│  [📅 Hoy]    [🏗️ Obras]    [🌿 Servicios]    [⚙️ Más]  │
└────────────────────────────────────────────────────────┘
```

---

### 2.2 Menú Rápido Contextual (Speed Dial / BottomSheet del FAB `+`)

Al presionar el botón central flotante `(+)`, se abre una hoja inferior ultra-rápida pensada para registrar movimientos con una sola mano en campo:

```
┌────────────────────────────────────────────────────────┐
│ ⚡ REGISTRO RÁPIDO EN CAMPO                    [ ✕ ]   │
├────────────────────────────────────────────────────────┤
│                                                        │
│   [ 💰 Registrar Gasto ]       [ 👷 Registrar Jornada ]│
│   Gasolina, comida, viático...   Jornal de peón / peones│
│                                                        │
│   [ 📦 Consumir Material ]     [ 🔧 Entregar/Devolver ]│
│   Plantas, tubos, abono a obra   Herramientas en bodega│
│                                                        │
│   [ 📷 Capturar Evidencia ]    [ 💵 Registrar Cobro ]  │
│   Foto antes / después           Pago recibido de cliente│
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

### 2.3 Formulario de Registro Rápido de Jornadas (WorkLog)

```
┌────────────────────────────────────────────────────────┐
│ ← Registrar Jornal de Cuadrilla               [ Guardar ]│
├────────────────────────────────────────────────────────┤
│ 👷 Trabajador:                                         │
│ ┌────────────────────────────────────────────────────┐ │
│ │ [ Carlos Quispe - Jardinero (S/ 80.00/día)     ▼ ] │ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
│ 🏗️ Imputar a Proyecto / Obra:                          │
│ ┌────────────────────────────────────────────────────┐ │
│ │ [ Obra: Torre B - Red Hidráulica               ▼ ] │ │
│ └────────────────────────────────────────────────────┘ │
│                                                        │
│ 📅 Fecha: [ 04/10/2026 📅 ]   Modalidad: [ Día (x1) ▼ ]│
│                                                        │
│ 💵 Tarifa Acordada: [ S/ 80.00 ]                       │
│                                                        │
│ 🔘 Estado de Pago:                                     │
│ ( ) Pendiente de Pago                                  │
│ (•) Pagado en Efectivo en Campo                        │
│     └► Pagado por: [ Yoset (Socio 1) ▼ ]              │
│                                                        │
│ 📝 Tarea Realizada (Opcional):                         │
│ [ Zanjado para línea de tubería 2" y limpieza        ] │
└────────────────────────────────────────────────────────┘
```

---

### 2.4 Ficha Detallada de Obra con Costeo en Vivo (Project Detail View)

```
┌────────────────────────────────────────────────────────┐
│ ← OBR-2026-001 • Torre B Red Hidráulica       [ ⚙️ Edit ]│
├────────────────────────────────────────────────────────┤
│ Cliente: Residencial Los Álamos │ Estado: En Progreso  │
│ Ubicación: Av. Principal #450, Cayma                   │
├────────────────────────────────────────────────────────┤
│ 📊 RESUMEN ECONÓMICO EN VIVO:                          │
│ Presupuesto Contratado:       S/ 45,000.00             │
│ Cobrado a la fecha (40%):     S/ 18,000.00             │
│ ────────────────────────────────────────────────────── │
│ 🔴 Costos Reales Incurridos:  S/ 14,250.00             │
│   • 👷 Jornales (12 días):    S/  3,840.00             │
│   • 📦 Materiales consumidos: S/  8,410.00             │
│   • ⛽ Gastos directos:       S/  2,000.00             │
│ ────────────────────────────────────────────────────── │
│ 🟢 Margen Bruto Actual:       S/  3,750.00 (20.8% s/cob)│
├────────────────────────────────────────────────────────┤
│ [ Jornadas (8) ]  [ Insumos (14) ]  [ Gastos ]  [ Fotos]│
├────────────────────────────────────────────────────────┤
│ 📦 ÚLTIMOS MATERIALES CONSUMIDOS EN ESTA OBRA:         │
│ • 40 u. Tubo PVC 2" Hidráulico       (S/ 38.00 c/u)    │
│ • 15 kg Pegamento Oatey PVC          (S/ 45.00 c/u)    │
│ • 12 u. Válvulas Esféricas Bronce    (S/ 65.00 c/u)    │
│                                                        │
│ 🔧 HERRAMIENTAS ACTUALMENTE EN ESTA OBRA:              │
│ • 🛠️ Termofusora 800W (En custodia de: Carlos Quispe)  │
│ • ⛏️ Rotomartillo SDS Max (En custodia de: Yoset)      │
└────────────────────────────────────────────────────────┘
```

---

## 3. Wireframes ASCII: Portal de Administración Web (Desktop Master-Detail)

### 3.1 Layout General del Panel Web (Sidebar + TopBar + Workspace)

```
┌──────────────┬──────────────────────────────────────────────────────────────────────────────────┐
│ DECOLUMAX 🌿 │ 🔍 Buscar obra, cliente, material...        🔔 (3)   🏢 Decolumax Arequipa  👤 ▼│
├──────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 📊 Dashboard │ TABLERO DE CONTROL GENERAL                                   [ + Nueva Obra ]     │
│ 🏗️ Obras      ├────────────────────┬────────────────────┬────────────────────┬──────────────────┤
│ 🌿 Servicios │ 💼 OBRAS ACTIVAS   │ 🛠️ SERVICIOS 7 DÍAS│ 📦 STOCK CRÍTICO   │ ⚖️ BALANCE SOCIOS │
│ 📦 Inventario│        3           │        5           │    2 Insumos       │ S1 debe S/ 450 a │
│ 🔧 Equipos   │ S/ 115,000 Presup. │ 2 Urgentes HOY     │ Plantas Mioporo    │ Socio 2          │
│ 👷 Personal  ├────────────────────┴────────────────────┴────────────────────┴──────────────────┤
│ 👥 Clientes  │ 📈 RENTABILIDAD Y EJECUCIÓN DE OBRAS:                                            │
│ 🏢 Proveedor │ ┌──────────────────┬─────────────┬────────────┬─────────────┬──────────┬───────┐ │
│ ⚖️ Finanzas   │ │ Código / Obra    │ Cliente     │ Presupuesto│ Costo Real  │ Margen   │ Estado│ │
│ 📅 Calendario│ ├──────────────────┼─────────────┼────────────┼─────────────┼──────────┼───────┤ │
│ ⚙️ Ajustes   │ │ OBR-001 Torre B  │ Los Álamos  │ S/ 45,000  │ S/ 14,250   │ + 68.3%  │ [🟢]  │ │
│              │ │ OBR-002 Jardines │ San Marcos  │ S/ 12,000  │ S/  7,800   │ + 35.0%  │ [🟢]  │ │
│              │ │ OBR-003 Riego    │ Terreno Sach│ S/ 28,000  │ S/ 26,900   │ +  3.9%  │ [🟡]  │ │
│              │ └──────────────────┴─────────────┴────────────┴─────────────┴──────────┴───────┘ │
└──────────────┴──────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Vista Master-Detail: Custodia de Herramientas y Activos en Web

```
┌──────────────┬──────────────────────────────────────────────────────────────────────────────────┐
│ 🔧 Herram.   │ INVENTARIO Y CUSTODIA DE HERRAMIENTAS                          [ + Nuevo Activo ]│
├──────────────┼───────────────────────────┬──────────────────────────────────────────────────────┤
│ [ Filtros: ] │ LISTADO DE HERRAMIENTAS   │ DETALLE DEL ACTIVO: HER-001                          │
│ Todos (18)   ├───────────────────────────┼──────────────────────────────────────────────────────┤
│ En Obra (10) │ 🔴 HER-001                │ 🛠️ Desbrozadora Stihl FS 250 (Gasolina)             │
│ En Bodega(6) │ Desbrozadora Stihl FS 250 │ Código: HER-001  │ Serie: ST-889124                  │
│ Taller (2)   │ [ En Obra: Torre B ]      │ Estado: 🔴 ASIGNADA EN CAMPO                         │
│              ├───────────────────────────┤ Responsable actual: Carlos Quispe (Jardinero)        │
│ 🔍 Buscar... │ 🟢 HER-002                │ Asignada desde: 02/10/2026 (hace 2 días)             │
│              │ Cortasetos Eléctrico 600W │ Destino: Obra Residencial Los Álamos - Torre B       │
│              │ [ En Bodega Central ]     ├──────────────────────────────────────────────────────┤
│              ├───────────────────────────┤ 📜 HISTORIAL DE CUSTODIA (CHECK-OUT / CHECK-IN):     │
│              │ 🟢 HER-003                │ • 02/10/2026: Entregada a Carlos Quispe (Obra 001)   │
│              │ Motosierra Husqvarna 120  │ • 28/09/2026: Devuelta a Bodega por Yoset (Limpia)   │
│              │ [ En Bodega Central ]     │ • 15/09/2026: Mantenimiento Preventivo (Cambio bujía)│
│              ├───────────────────────────┤                                                      │
│              │ 🟡 HER-004                │ [ 🔄 Devolver a Bodega ]   [ ⚙️ Registrar Servicio ] │
│              │ Bomba Sumergible 1.5 HP   │                                                      │
└──────────────┴───────────────────────────┴──────────────────────────────────────────────────────┘
```

---

## 4. Breakpoints y Estrategia Adaptativa / Responsive

| Dispositivo | Ancho (Breakpoint) | Navegación Principal | Tipo de Vistas | Diálogos y Formularios |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile** | `< 600 px` | `NavigationBar` inferior (4 pestañas) + FAB SpeedDial. | Tarjetas verticales, listas infinitas, swipe actions. | `ModalBottomSheet` expandible o pantalla completa. |
| **Tablet** | `600 px - 1024 px` | `NavigationRail` lateral izquierdo compacto. | Cuadrícula de tarjetas (2 columnas) o Split View. | Diálogos modales centrados (`AlertDialog` 500px). |
| **Desktop / Web** | `> 1024 px` | `Sidebar` permanente expandido con categorías. | Tablas densas de datos con ordenación + Master-Detail. | Panel lateral deslizante (`SideSheet`) o modal flotante. |

---

## 5. Catálogo de Componentes Reutilizables Compartidos

1. **`MoneyField`**: Input especializado para moneda con teclado numérico formateado y validación de decimales.
2. **`WorkerSelector`**: Dropdown con avatar y tarifa predeterminada para asignación de jornadas en 1 toque.
3. **`InventoryPicker`**: Selector con autocompletado y visualización de stock disponible en tiempo real.
4. **`StatusChip`**: Chip con código de color industrial para estados (`En Progreso`, `Urgente`, `Completado`, `Vencido`).
5. **`BalanceCard`**: Tarjeta visual que muestra la resolución de deudas netas entre socios de manera concisa.
6. **`AttachmentGallery`**: Carrusel de fotos de campo categorizadas por *Antes / Durante / Después / Comprobante*.
7. **`ResponsiveLayout`**: Widget wrapper que alterna automáticamente entre `Scaffold` móvil con barra inferior y `MasterDetailLayout` desktop.
