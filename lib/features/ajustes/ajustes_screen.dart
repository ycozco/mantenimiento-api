import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_screen.dart';

class AjustesScreen extends StatelessWidget {
  final LocalStorageService storage;

  const AjustesScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.settings, color: Colors.grey, size: 24),
            SizedBox(width: 10),
            Text('Ajustes y Respaldo'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección Logística y Almacén
          const Text(
            'LOGÍSTICA Y CONTROL OPERATIVO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.emeraldSuccess,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    LucideIcons.package,
                    color: AppTheme.emeraldSuccess,
                  ),
                  title: const Text(
                    'Inventario de Insumos y Materiales',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: const Text(
                    'Kardex, stock de plantas, fertilizantes, tierra y consumo por obra/mantenimiento.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InventoryScreen(storage: storage),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sección Respaldo Local
          const Text(
            'COPIA DE SEGURIDAD LOCAL (SIN LOGIN)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.amberSafety,
              letterSpacing: 0.5,
            ),
          ),
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
                    'Exportar Respaldo de Datos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: const Text(
                    'Genera un archivo JSON con todos los mantenimientos, obras y gastos para compartir con tu socio por WhatsApp o guardar en disco.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevron_right,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () async {
                    await storage.exportarRespaldo();
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
                      color: Colors.white,
                    ),
                  ),
                  subtitle: const Text(
                    'Pega el texto JSON de un respaldo para recuperar o sincronizar la información.',
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

          // Sección Notificaciones
          const Text(
            'SISTEMA DE ALERTAS ANTICIPADAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.amberSafety,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.bell_ring,
                        color: AppTheme.amberSafety,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Reglas de Notificación Local',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildReglaAlerta(
                    '🔔 1 Semana antes (7 días)',
                    'Aviso previo para preparar repuestos y herramientas.',
                  ),
                  _buildReglaAlerta(
                    '🔔 3 Días antes',
                    'Recordatorio de confirmación de cita.',
                  ),
                  _buildReglaAlerta(
                    '🔔 2 Días antes',
                    'Alerta de asignación de vehículo y gasolina.',
                  ),
                  _buildReglaAlerta(
                    '🔔 1 Día antes (Mañana)',
                    'Alerta prioritaria para el servicio del día siguiente.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.amberSafety.withValues(
                        alpha: 0.15,
                      ),
                      foregroundColor: AppTheme.amberSafety,
                      side: const BorderSide(
                        color: AppTheme.amberSafety,
                        width: 1,
                      ),
                    ),
                    icon: const Icon(LucideIcons.bell, size: 16),
                    label: const Text(
                      'Probar Notificación en este Dispositivo',
                    ),
                    onPressed: () async {
                      await NotificationService().mostrarNotificacionInmediata(
                        titulo: 'Prueba de Alerta de Mantenimiento',
                        cuerpo:
                            '¡Las notificaciones locales están configuradas y funcionando con éxito!',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notificación de prueba enviada.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sección Acerca de
          const Text(
            'INFORMACIÓN DEL SISTEMA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Planificador de Mantenimientos & Gastos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Versión 1.0.0 • 100% Offline (Sin servidor, sin login)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Base de datos local guardada en archivos del dispositivo con soporte para múltiples socios.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReglaAlerta(String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
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
                final exito = await storage.importarRespaldoJson(text);
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
