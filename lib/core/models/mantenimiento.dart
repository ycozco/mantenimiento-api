enum TipoFrecuencia {
  unMes,
  unMesYMedio,
  dosMeses,
  personalizado,
}

extension TipoFrecuenciaExt on TipoFrecuencia {
  String get etiqueta {
    switch (this) {
      case TipoFrecuencia.unMes:
        return '1 Mes (30d)';
      case TipoFrecuencia.unMesYMedio:
        return '1.5 Meses (45d)';
      case TipoFrecuencia.dosMeses:
        return '2 Meses (60d)';
      case TipoFrecuencia.personalizado:
        return 'Personalizado';
    }
  }

  int get diasDefault {
    switch (this) {
      case TipoFrecuencia.unMes:
        return 30;
      case TipoFrecuencia.unMesYMedio:
        return 45;
      case TipoFrecuencia.dosMeses:
        return 60;
      case TipoFrecuencia.personalizado:
        return 30;
    }
  }

  static TipoFrecuencia fromString(String val) {
    switch (val) {
      case 'unMesYMedio':
      case '1_5_meses':
        return TipoFrecuencia.unMesYMedio;
      case 'dosMeses':
      case '2_meses':
        return TipoFrecuencia.dosMeses;
      case 'personalizado':
      case 'custom':
        return TipoFrecuencia.personalizado;
      case 'unMes':
      case '1_mes':
      default:
        return TipoFrecuencia.unMes;
    }
  }
}

class Mantenimiento {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String titulo;
  final String? descripcion;
  final TipoFrecuencia tipoFrecuencia;
  final int diasPersonalizados;
  final DateTime fechaProximo;
  final DateTime? fechaUltimo;
  final List<String> responsablesIds; // IDs de los socios encargados
  final bool activo;
  final bool completado;

  const Mantenimiento({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.titulo,
    this.descripcion,
    this.tipoFrecuencia = TipoFrecuencia.unMes,
    this.diasPersonalizados = 30,
    required this.fechaProximo,
    this.fechaUltimo,
    this.responsablesIds = const [],
    this.activo = true,
    this.completado = false,
  });

  int get diasIntervalo {
    if (tipoFrecuencia == TipoFrecuencia.personalizado) {
      return diasPersonalizados > 0 ? diasPersonalizados : 30;
    }
    return tipoFrecuencia.diasDefault;
  }

  int get diasRestantes {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(fechaProximo.year, fechaProximo.month, fechaProximo.day);
    return target.difference(today).inDays;
  }

  bool get estaVencido => diasRestantes < 0;
  bool get esHoy => diasRestantes == 0;
  bool get esUrgente => diasRestantes >= 0 && diasRestantes <= 3;
  bool get proximaSemana => diasRestantes > 3 && diasRestantes <= 7;

  DateTime calcularProximoCiclo([DateTime? desdeFecha]) {
    final base = desdeFecha ?? DateTime.now();
    return base.add(Duration(days: diasIntervalo));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'titulo': titulo,
    'descripcion': descripcion,
    'tipoFrecuencia': tipoFrecuencia.name,
    'diasPersonalizados': diasPersonalizados,
    'fechaProximo': fechaProximo.toIso8601String(),
    'fechaUltimo': fechaUltimo?.toIso8601String(),
    'responsablesIds': responsablesIds,
    'activo': activo,
    'completado': completado,
  };

  factory Mantenimiento.fromJson(Map<String, dynamic> json) => Mantenimiento(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    clienteNombre: json['clienteNombre'] as String? ?? 'Cliente',
    titulo: json['titulo'] as String,
    descripcion: json['descripcion'] as String?,
    tipoFrecuencia: TipoFrecuenciaExt.fromString(json['tipoFrecuencia'] as String? ?? 'unMes'),
    diasPersonalizados: json['diasPersonalizados'] as int? ?? 30,
    fechaProximo: DateTime.parse(json['fechaProximo'] as String),
    fechaUltimo: json['fechaUltimo'] != null ? DateTime.parse(json['fechaUltimo'] as String) : null,
    responsablesIds: (json['responsablesIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    activo: json['activo'] as bool? ?? true,
    completado: json['completado'] as bool? ?? false,
  );

  Mantenimiento copyWith({
    String? id,
    String? clienteId,
    String? clienteNombre,
    String? titulo,
    String? descripcion,
    TipoFrecuencia? tipoFrecuencia,
    int? diasPersonalizados,
    DateTime? fechaProximo,
    DateTime? fechaUltimo,
    List<String>? responsablesIds,
    bool? activo,
    bool? completado,
  }) => Mantenimiento(
    id: id ?? this.id,
    clienteId: clienteId ?? this.clienteId,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    tipoFrecuencia: tipoFrecuencia ?? this.tipoFrecuencia,
    diasPersonalizados: diasPersonalizados ?? this.diasPersonalizados,
    fechaProximo: fechaProximo ?? this.fechaProximo,
    fechaUltimo: fechaUltimo ?? this.fechaUltimo,
    responsablesIds: responsablesIds ?? this.responsablesIds,
    activo: activo ?? this.activo,
    completado: completado ?? this.completado,
  );
}
