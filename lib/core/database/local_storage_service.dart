import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../models/socio.dart';
import '../models/cliente.dart';
import '../models/mantenimiento.dart';
import '../models/obra.dart';
import '../models/gasto.dart';
import '../notifications/notification_service.dart';

class LocalStorageService extends ChangeNotifier {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  List<Socio> _socios = [];
  List<Cliente> _clientes = [];
  List<Mantenimiento> _mantenimientos = [];
  List<Obra> _obras = [];
  List<Gasto> _gastos = [];

  List<Socio> get socios => List.unmodifiable(_socios);
  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Mantenimiento> get mantenimientos => List.unmodifiable(_mantenimientos);
  List<Obra> get obras => List.unmodifiable(_obras);
  List<Gasto> get gastos => List.unmodifiable(_gastos);

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromLocal();
    _initialized = true;
    notifyListeners();
  }

  // Archivo local de persistencia
  Future<File?> _getLocalFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/mantenimiento_data.json');
    } catch (e) {
      debugPrint('Error obteniendo directorio local: $e');
      return null;
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      String? jsonStr;
      final file = await _getLocalFile();
      if (file != null && await file.exists()) {
        jsonStr = await file.readAsString();
      }

      // Respaldo en SharedPreferences si no se encontró en archivo
      if (jsonStr == null || jsonStr.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        jsonStr = prefs.getString('mantenimiento_backup_key');
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        _deserialize(jsonStr);
      } else {
        _seedInitialData();
      }
    } catch (e) {
      debugPrint('Error cargando datos locales: $e');
      _seedInitialData();
    }
  }

  void _seedInitialData() {
    _socios = [
      const Socio(id: 's1', nombre: 'Socio 1 (Tú)', telefono: '', colorValue: 0xFFF59E0B),
      const Socio(id: 's2', nombre: 'Socio 2', telefono: '', colorValue: 0xFF10B981),
    ];

    _clientes = [
      const Cliente(
        id: 'c1',
        nombre: 'Residencial Los Álamos',
        telefono: '555-0192',
        direccion: 'Av. Principal #450',
        notas: 'Revisión bombas de agua y tableros',
      ),
      const Cliente(
        id: 'c2',
        nombre: 'Clínica San Marcos',
        telefono: '555-8821',
        direccion: 'Calle Médicos 12',
        notas: 'Aire acondicionado y generador',
      ),
    ];

    final now = DateTime.now();
    _mantenimientos = [
      Mantenimiento(
        id: 'm1',
        clienteId: 'c1',
        clienteNombre: 'Residencial Los Álamos',
        titulo: 'Mantenimiento Preventivo Bombas',
        tipoFrecuencia: TipoFrecuencia.unMesYMedio,
        diasPersonalizados: 45,
        fechaProximo: now.add(const Duration(days: 3)), // En 3 días (alerta activa)
        responsablesIds: ['s1', 's2'],
      ),
      Mantenimiento(
        id: 'm2',
        clienteId: 'c2',
        clienteNombre: 'Clínica San Marcos',
        titulo: 'Inspección Eléctrica y Climas',
        tipoFrecuencia: TipoFrecuencia.unMes,
        diasPersonalizados: 30,
        fechaProximo: now.add(const Duration(days: 7)), // En 1 semana
        responsablesIds: ['s1'],
      ),
    ];

    _obras = [
      Obra(
        id: 'o1',
        nombre: 'Instalación Red Hidráulica Torre B',
        clienteId: 'c1',
        clienteNombre: 'Residencial Los Álamos',
        presupuesto: 45000.0,
        fechaInicio: now.subtract(const Duration(days: 10)),
        sociosAsignados: ['s1', 's2'],
      ),
    ];

    _gastos = [
      Gasto(
        id: 'g1',
        concepto: 'Gasolina para camioneta de trabajo',
        categoria: CategoriaGasto.gasolina,
        montoTotal: 850.0,
        fecha: now.subtract(const Duration(days: 2)),
        pagadoPorSocioId: 's1',
        tipoReparto: TipoReparto.equitativo,
        participaciones: {'s1': 1.0, 's2': 1.0},
        nota: 'Traslado a Los Álamos',
      ),
      Gasto(
        id: 'g2',
        concepto: 'Materiales tubería PVC y selladores',
        categoria: CategoriaGasto.materialesObra,
        montoTotal: 3400.0,
        fecha: now.subtract(const Duration(days: 1)),
        pagadoPorSocioId: 's2',
        obraId: 'o1',
        obraNombre: 'Instalación Red Hidráulica Torre B',
        tipoReparto: TipoReparto.equitativo,
        participaciones: {'s1': 1.0, 's2': 1.0},
      ),
    ];

    _saveToLocal();
  }

  Future<void> _saveToLocal() async {
    try {
      final jsonStr = _serialize();
      final file = await _getLocalFile();
      if (file != null) {
        await file.writeAsString(jsonStr, flush: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mantenimiento_backup_key', jsonStr);
    } catch (e) {
      debugPrint('Error guardando localmente: $e');
    }
  }

  String _serialize() {
    final Map<String, dynamic> data = {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'socios': _socios.map((s) => s.toJson()).toList(),
      'clientes': _clientes.map((c) => c.toJson()).toList(),
      'mantenimientos': _mantenimientos.map((m) => m.toJson()).toList(),
      'obras': _obras.map((o) => o.toJson()).toList(),
      'gastos': _gastos.map((g) => g.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  void _deserialize(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['socios'] != null) {
        _socios = (data['socios'] as List).map((e) => Socio.fromJson(e)).toList();
      }
      if (data['clientes'] != null) {
        _clientes = (data['clientes'] as List).map((e) => Cliente.fromJson(e)).toList();
      }
      if (data['mantenimientos'] != null) {
        _mantenimientos = (data['mantenimientos'] as List).map((e) => Mantenimiento.fromJson(e)).toList();
      }
      if (data['obras'] != null) {
        _obras = (data['obras'] as List).map((e) => Obra.fromJson(e)).toList();
      }
      if (data['gastos'] != null) {
        _gastos = (data['gastos'] as List).map((e) => Gasto.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error deserializando datos: $e');
    }
  }

  // --- CRUD SOCIOS ---
  Future<void> agregarSocio(Socio socio) async {
    _socios.add(socio);
    await _saveToLocal();
    notifyListeners();
  }

  Future<void> editarSocio(Socio socio) async {
    final idx = _socios.indexWhere((s) => s.id == socio.id);
    if (idx != -1) {
      _socios[idx] = socio;
      await _saveToLocal();
      notifyListeners();
    }
  }

  Future<void> eliminarSocio(String socioId) async {
    if (_socios.length <= 1) return; // Mantener al menos 1
    _socios.removeWhere((s) => s.id == socioId);
    await _saveToLocal();
    notifyListeners();
  }

  // --- CRUD CLIENTES ---
  Future<void> agregarCliente(Cliente cliente) async {
    _clientes.add(cliente);
    await _saveToLocal();
    notifyListeners();
  }

  Future<void> editarCliente(Cliente cliente) async {
    final idx = _clientes.indexWhere((c) => c.id == cliente.id);
    if (idx != -1) {
      _clientes[idx] = cliente;
      await _saveToLocal();
      notifyListeners();
    }
  }

  Future<void> eliminarCliente(String clienteId) async {
    _clientes.removeWhere((c) => c.id == clienteId);
    await _saveToLocal();
    notifyListeners();
  }

  // --- CRUD MANTENIMIENTOS ---
  Future<void> agregarMantenimiento(Mantenimiento m) async {
    _mantenimientos.add(m);
    await _saveToLocal();
    await NotificationService().programarAlertasMantenimiento(m);
    notifyListeners();
  }

  Future<void> editarMantenimiento(Mantenimiento m) async {
    final idx = _mantenimientos.indexWhere((item) => item.id == m.id);
    if (idx != -1) {
      _mantenimientos[idx] = m;
      await _saveToLocal();
      await NotificationService().programarAlertasMantenimiento(m);
      notifyListeners();
    }
  }

  Future<void> completarMantenimiento(String id) async {
    final idx = _mantenimientos.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final actual = _mantenimientos[idx];
      // Programamos el siguiente ciclo automáticamente
      final proximaFecha = actual.calcularProximoCiclo(DateTime.now());
      final actualizado = actual.copyWith(
        fechaUltimo: DateTime.now(),
        fechaProximo: proximaFecha,
        completado: false,
      );
      _mantenimientos[idx] = actualizado;
      await _saveToLocal();
      await NotificationService().programarAlertasMantenimiento(actualizado);
      notifyListeners();
    }
  }

  Future<void> eliminarMantenimiento(String id) async {
    await NotificationService().cancelarAlertasMantenimiento(id);
    _mantenimientos.removeWhere((m) => m.id == id);
    await _saveToLocal();
    notifyListeners();
  }

  // --- CRUD OBRAS ---
  Future<void> agregarObra(Obra obra) async {
    _obras.add(obra);
    await _saveToLocal();
    notifyListeners();
  }

  Future<void> editarObra(Obra obra) async {
    final idx = _obras.indexWhere((o) => o.id == obra.id);
    if (idx != -1) {
      _obras[idx] = obra;
      await _saveToLocal();
      notifyListeners();
    }
  }

  Future<void> eliminarObra(String obraId) async {
    _obras.removeWhere((o) => o.id == obraId);
    await _saveToLocal();
    notifyListeners();
  }

  // --- CRUD GASTOS ---
  Future<void> agregarGasto(Gasto gasto) async {
    _gastos.insert(0, gasto);
    await _saveToLocal();
    notifyListeners();
  }

  Future<void> editarGasto(Gasto gasto) async {
    final idx = _gastos.indexWhere((g) => g.id == gasto.id);
    if (idx != -1) {
      _gastos[idx] = gasto;
      await _saveToLocal();
      notifyListeners();
    }
  }

  Future<void> eliminarGasto(String gastoId) async {
    _gastos.removeWhere((g) => g.id == gastoId);
    await _saveToLocal();
    notifyListeners();
  }

  // --- EXPORTAR / IMPORTAR RESPALDO ---
  Future<void> exportarRespaldo() async {
    final jsonContent = _serialize();
    if (kIsWeb) {
      debugPrint('Exportar en web');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/mantenimiento_respaldo_${DateTime.now().millisecondsSinceEpoch}.json');
      await backupFile.writeAsString(jsonContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupFile.path)],
          subject: 'Copia de Respaldo Mantenimientos y Gastos',
          text: 'Copia local de seguridad generada desde la app de Mantenimiento.',
        ),
      );
    } catch (e) {
      debugPrint('Error exportando respaldo: $e');
    }
  }

  Future<bool> importarRespaldoJson(String jsonStr) async {
    try {
      _deserialize(jsonStr);
      await _saveToLocal();
      // Reprogramar alertas para todos los mantenimientos activos
      for (final m in _mantenimientos) {
        await NotificationService().programarAlertasMantenimiento(m);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al importar json: $e');
      return false;
    }
  }
}
