import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/company_settings.dart';
import '../../core/models/device_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../tools/tools_screen.dart';

class AjustesScreen extends StatefulWidget {
  final LocalStorageService storage;

  const AjustesScreen({super.key, required this.storage});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  late Future<CompanySettings> _companySettingsFuture;
  late Future<DevicePreferences> _devicePreferencesFuture;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _companySettingsFuture = widget.storage.settingsRepository.getSettings();
    _devicePreferencesFuture = widget.storage.devicePreferencesService
        .getPreferences();
  }

  void _reload() {
    setState(() {
      _loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.settings, color: Colors.grey, size: 24),
            SizedBox(width: 10),
            Text('Ajustes y Configuración'),
          ],
        ),
      ),
      body: FutureBuilder<CompanySettings>(
        future: _companySettingsFuture,
        builder: (context, companySnap) {
          final company = companySnap.data ?? CompanySettings.defaults();

          return FutureBuilder<DevicePreferences>(
            future: _devicePreferencesFuture,
            builder: (context, deviceSnap) {
              final device = deviceSnap.data ?? const DevicePreferences();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ==========================================
                  // 1. SECCIÓN EMPRESA (Workspace Settings)
                  // ==========================================
                  _buildSectionHeader('EMPRESA', AppTheme.skyAccent),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    company.companyName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (company.legalName != null &&
                                      company.legalName!.isNotEmpty)
                                    Text(
                                      company.legalName!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.pencil, size: 18),
                                color: AppTheme.skyAccent,
                                tooltip: 'Editar datos de la empresa',
                                onPressed: () =>
                                    _showEditCompanyDialog(context, company),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFF334155)),
                          _buildDetailRow(
                            'Moneda operativa:',
                            '${company.currency} (Soles)',
                          ),
                          _buildDetailRow('Zona horaria:', company.timezone),
                          if (company.ruc != null && company.ruc!.isNotEmpty)
                            _buildDetailRow('RUC:', company.ruc!),
                          if (company.phone != null &&
                              company.phone!.isNotEmpty)
                            _buildDetailRow('Teléfono:', company.phone!),
                          if (company.email != null &&
                              company.email!.isNotEmpty)
                            _buildDetailRow('Correo:', company.email!),
                          if (company.address != null &&
                              company.address!.isNotEmpty)
                            _buildDetailRow('Dirección:', company.address!),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 2. SECCIÓN OPERACIONES (Defaults operacionales)
                  // ==========================================
                  _buildSectionHeader('OPERACIONES', AppTheme.emeraldSuccess),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Permitir Stock Negativo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Permite registrar salidas de materiales aún si el inventario actual es 0.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          value: company.allowNegativeStock,
                          activeTrackColor: AppTheme.emeraldSuccess,
                          onChanged: (val) async {
                            await widget.storage.settingsRepository
                                .setAllowNegativeStock(val);
                            _reload();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF334155)),
                        ListTile(
                          title: const Text(
                            'Jornada laboral estándar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            '${company.defaultWorkDayHours.toStringAsFixed(1)} hrs',
                            style: const TextStyle(
                              color: AppTheme.skyAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFF334155)),
                        // Accesos rápidos a catálogos operativos
                        ListTile(
                          leading: const Icon(
                            LucideIcons.package,
                            color: AppTheme.emeraldSuccess,
                            size: 20,
                          ),
                          title: const Text(
                            'Catálogo de Inventario y Kardex',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InventoryScreen(storage: widget.storage),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            LucideIcons.wrench,
                            color: AppTheme.skyAccent,
                            size: 20,
                          ),
                          title: const Text(
                            'Custodia de Herramientas y Equipos',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ToolsScreen(storage: widget.storage),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            LucideIcons.store,
                            color: AppTheme.amberSafety,
                            size: 20,
                          ),
                          title: const Text(
                            'Directorio de Proveedores',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SuppliersScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 3. SECCIÓN NOTIFICACIONES
                  // ==========================================
                  _buildSectionHeader('NOTIFICACIONES', AppTheme.amberSafety),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Notificaciones Locales',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Alertas anticipadas en el dispositivo para visitas de mantenimiento.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            value: device.notificationsEnabled,
                            activeTrackColor: AppTheme.amberSafety,
                            onChanged: (val) async {
                              await widget.storage.devicePreferencesService
                                  .setNotificationsEnabled(val);
                              _reload();
                            },
                          ),
                          const Divider(height: 16, color: Color(0xFF334155)),
                          const Text(
                            'Reglas de Anticipación (Hora: 09:00 AM)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildNotificationRule(
                            '7 días antes',
                            'Aviso temprano para cotizar o pedir insumos.',
                          ),
                          _buildNotificationRule(
                            '3 días antes',
                            'Confirmación con el cliente.',
                          ),
                          _buildNotificationRule(
                            '2 días antes',
                            'Revisión y alistamiento de herramientas.',
                          ),
                          _buildNotificationRule(
                            '1 día antes',
                            'Asignación final de cuadrilla de operarios.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 4. SECCIÓN BACKUP Y DATOS
                  // ==========================================
                  _buildSectionHeader('BACKUP Y DATOS', AppTheme.skyAccent),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            LucideIcons.share_2,
                            color: AppTheme.emeraldSuccess,
                          ),
                          title: const Text(
                            'Exportar Copia de Seguridad',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Genera un archivo JSON de respaldo completo para transferir o respaldar.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevron_right,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onTap: () async {
                            await widget.storage.exportarRespaldo();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFF334155)),
                        ListTile(
                          leading: const Icon(
                            LucideIcons.download,
                            color: AppTheme.skyAccent,
                          ),
                          title: const Text(
                            'Restaurar Copia de Seguridad',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Carga un archivo de respaldo JSON para restaurar el estado de la base de datos.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevron_right,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onTap: () => _mostrarDialogoImportar(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 5. SECCIÓN SISTEMA (Preferencias del Dispositivo)
                  // ==========================================
                  _buildSectionHeader('SISTEMA', Colors.grey),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Workspace ID:',
                            AppConstants.defaultWorkspaceId,
                          ),
                          _buildDetailRow('Versión de la app:', '1.0.0+1'),
                          _buildDetailRow(
                            'Motor de base de datos:',
                            'Drift / SQLite Local-First',
                          ),
                          _buildDetailRow(
                            'Tema del dispositivo:',
                            device.themeMode.toUpperCase(),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Los datos de la empresa y operaciones se almacenan localmente en el dispositivo.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRule(String time, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.bell, size: 14, color: AppTheme.amberSafety),
          const SizedBox(width: 8),
          Text(
            '$time: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCompanyDialog(BuildContext context, CompanySettings current) {
    final nameCtrl = TextEditingController(text: current.companyName);
    final legalCtrl = TextEditingController(text: current.legalName ?? '');
    final rucCtrl = TextEditingController(text: current.ruc ?? '');
    final phoneCtrl = TextEditingController(text: current.phone ?? '');
    final emailCtrl = TextEditingController(text: current.email ?? '');
    final addressCtrl = TextEditingController(text: current.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Text('Editar Datos de la Empresa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre Comercial *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: legalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Razón Social (Opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rucCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'RUC (11 dígitos, opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyAccent,
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final updated = current.copyWith(
                companyName: newName,
                legalName: legalCtrl.text.trim().isEmpty
                    ? null
                    : legalCtrl.text.trim(),
                ruc: rucCtrl.text.trim().isEmpty ? null : rucCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty
                    ? null
                    : emailCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty
                    ? null
                    : addressCtrl.text.trim(),
              );

              await widget.storage.settingsRepository.updateSettings(updated);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _reload();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoImportar(BuildContext context) {
    final jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Text('Restaurar Respaldo JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega el contenido del archivo de respaldo JSON generado previamente:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: jsonCtrl,
              maxLines: 6,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{"version": 1, "socios": [...], ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyAccent,
            ),
            onPressed: () async {
              final text = jsonCtrl.text.trim();
              if (text.isNotEmpty) {
                final exito = await widget.storage.importarRespaldoJson(text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        exito
                            ? '¡Respaldo importado correctamente!'
                            : 'Error al procesar el formato JSON.',
                      ),
                      backgroundColor: exito
                          ? AppTheme.emeraldSuccess
                          : AppTheme.coralUrgent,
                    ),
                  );
                }
              }
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}
