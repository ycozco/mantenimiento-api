# 🛠️ Mantenimientos & Gastos Compartidos (Flutter)

Aplicación multiplataforma en **Flutter**, 100% offline (sin login obligatorio ni servidores externos), diseñada para técnicos, contratistas y socios que realizan:
1. **Planificación de Mantenimientos Preventivos a Clientes** con alertas anticipadas escalonadas.
2. **Proyectos / Obras Independientes** con seguimiento de inversiones.
3. **División de Gastos Compartidos** (Gasolina, Mantenimiento de Equipos/Auto, Comida, Insumos) entre 2 o más personas con balance automático (*"¿Quién le debe a quién?"*).

---

## 🚀 Características Principales

### 🔔 Alertas Escalonadas de Mantenimiento
- **Notificaciones locales automáticas** programadas para cada servicio:
  - 1 semana antes (**7 días**)
  - **3 días** antes
  - **2 días** antes
  - **1 día** antes (¡Mañana!)
- **Frecuencias de Mantenimiento**:
  - `1 Mes` (30 días)
  - `1.5 Meses` (45 días)
  - `2 Meses` (60 días)
  - `Personalizado` (N días a elegir)
- **Ciclo Automático**: Al pulsar *"Completar & Re-programar"*, el sistema calcula de inmediato la próxima fecha y reprograma las alertas correspondientes.

### 💰 Gastos de Inversión y Balance de Socios
- **2 o más Socios**: Registro con colores identificativos para avatares y chips.
- **Categorías**: Gasolina / Combustible, Mantenimiento de Equipos, Comidas, Materiales de Obra, Herramientas, Viáticos.
- **Modos de Reparto**:
  - **Equitativo (Partes Iguales)**: División entre los socios seleccionados.
  - **Porcentual / Por Partes**: Asignación de porcentajes (ej. 70% / 30%).
- **Balance y Liquidación**: Algoritmo que calcula el saldo neto de cada socio y muestra de forma clara:
  > *"Socio 2 debe pagar \$500.00 a Socio 1 (Tú)"*

### 💾 Almacenamiento 100% Local y Respaldo
- Sin login ni bases de datos en la nube.
- Persistencia en archivo JSON local + SharedPreferences.
- **Botón de Exportar Respaldo**: Permite generar un archivo JSON y compartirlo por WhatsApp, email o guardarlo en disco para restaurarlo en otro dispositivo.

### 🎨 Diseño Visual & Iconografía
- **Iconografía**: `flutter_lucide` (iconos lineales modernos y consistentes).
- **Paleta Industrial Precision**:
  - Slate Dark: `#0F172A` / `#1E293B`
  - Acento Ámbar Seguridad: `#F59E0B`
  - Acento Éxito Finanzas: `#10B981`
  - Acento Urgente: `#EF4444`
  - Acento Obras: `#0EA5E9`

---

## 📱 Ejecutar la Aplicación

Para ejecutar en tu máquina (Windows Desktop o Chrome Web):
```bash
# En Windows Desktop
flutter run -d windows

# En Navegador Web
flutter run -d chrome
```

Para compilar el APK de Android:
```bash
flutter build apk --release
```
