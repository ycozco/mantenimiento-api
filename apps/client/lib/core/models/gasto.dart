enum CategoriaGasto {
  gasolina,
  mantenimientoVehiculoHerramienta,
  comida,
  materialesObra,
  herramientas,
  viaticos,
  otro,
}

extension CategoriaGastoExt on CategoriaGasto {
  String get etiqueta {
    switch (this) {
      case CategoriaGasto.gasolina:
        return 'Gasolina / Combustible';
      case CategoriaGasto.mantenimientoVehiculoHerramienta:
        return 'Mantenimiento Equipos / Auto';
      case CategoriaGasto.comida:
        return 'Comida / Refrigerios';
      case CategoriaGasto.materialesObra:
        return 'Materiales para Obra';
      case CategoriaGasto.herramientas:
        return 'Compra de Herramientas';
      case CategoriaGasto.viaticos:
        return 'Viáticos / Peajes';
      case CategoriaGasto.otro:
        return 'Otros Gastos';
    }
  }

  static CategoriaGasto fromString(String val) {
    for (final cat in CategoriaGasto.values) {
      if (cat.name == val) return cat;
    }
    return CategoriaGasto.otro;
  }
}

enum TipoReparto {
  equitativo, // Partes iguales entre los participantes
  porPartes, // Porcentajes o proporciones (ej. 60% / 40%)
  montoFijo, // Montos exactos asignados a cada uno
}

extension TipoRepartoExt on TipoReparto {
  String get etiqueta {
    switch (this) {
      case TipoReparto.equitativo:
        return 'Equitativo (Partes Iguales)';
      case TipoReparto.porPartes:
        return 'Por Porcentaje / Partes';
      case TipoReparto.montoFijo:
        return 'Monto Específico por Socio';
    }
  }

  static TipoReparto fromString(String val) {
    for (final tr in TipoReparto.values) {
      if (tr.name == val) return tr;
    }
    return TipoReparto.equitativo;
  }
}

class Gasto {
  final String id;
  final String concepto;
  final CategoriaGasto categoria;
  final double montoTotal;
  final DateTime fecha;
  final String pagadoPorSocioId;
  final String? obraId;
  final String? obraNombre;
  final String? mantenimientoId;
  final TipoReparto tipoReparto;
  // Mapa de socioId -> participación:
  // Si equitativo: lista de IDs incluidos con valor 1.0
  // Si porPartes: socioId -> porcentaje (ej. 50.0, 50.0)
  // Si montoFijo: socioId -> monto en pesos/dólares asignado a cada uno
  final Map<String, double> participaciones;
  final String? nota;

  const Gasto({
    required this.id,
    required this.concepto,
    required this.categoria,
    required this.montoTotal,
    required this.fecha,
    required this.pagadoPorSocioId,
    this.obraId,
    this.obraNombre,
    this.mantenimientoId,
    this.tipoReparto = TipoReparto.equitativo,
    required this.participaciones,
    this.nota,
  });

  /// Calcula la cuota que le corresponde pagar a un socio en específico
  double cuotaDe(String socioId) {
    if (!participaciones.containsKey(socioId)) return 0.0;

    switch (tipoReparto) {
      case TipoReparto.equitativo:
        final count = participaciones.keys.length;
        if (count == 0) return 0.0;
        return montoTotal / count;
      case TipoReparto.porPartes:
        final porcentaje = participaciones[socioId] ?? 0.0;
        final totalPorcentajes = participaciones.values.fold(
          0.0,
          (a, b) => a + b,
        );
        if (totalPorcentajes <= 0) return 0.0;
        return (montoTotal * porcentaje) / totalPorcentajes;
      case TipoReparto.montoFijo:
        return participaciones[socioId] ?? 0.0;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'concepto': concepto,
    'categoria': categoria.name,
    'montoTotal': montoTotal,
    'fecha': fecha.toIso8601String(),
    'pagadoPorSocioId': pagadoPorSocioId,
    'obraId': obraId,
    'obraNombre': obraNombre,
    'mantenimientoId': mantenimientoId,
    'tipoReparto': tipoReparto.name,
    'participaciones': participaciones,
    'nota': nota,
  };

  factory Gasto.fromJson(Map<String, dynamic> json) => Gasto(
    id: json['id'] as String,
    concepto: json['concepto'] as String,
    categoria: CategoriaGastoExt.fromString(
      json['categoria'] as String? ?? 'otro',
    ),
    montoTotal: (json['montoTotal'] as num).toDouble(),
    fecha: DateTime.parse(json['fecha'] as String),
    pagadoPorSocioId: json['pagadoPorSocioId'] as String,
    obraId: json['obraId'] as String?,
    obraNombre: json['obraNombre'] as String?,
    mantenimientoId: json['mantenimientoId'] as String?,
    tipoReparto: TipoRepartoExt.fromString(
      json['tipoReparto'] as String? ?? 'equitativo',
    ),
    participaciones:
        (json['participaciones'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        {},
    nota: json['nota'] as String?,
  );
}
