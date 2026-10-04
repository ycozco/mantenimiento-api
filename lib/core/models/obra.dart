enum EstadoObra {
  planificada,
  enProgreso,
  finalizada,
  pausada,
}

extension EstadoObraExt on EstadoObra {
  String get etiqueta {
    switch (this) {
      case EstadoObra.planificada:
        return 'Planificada';
      case EstadoObra.enProgreso:
        return 'En Progreso';
      case EstadoObra.finalizada:
        return 'Finalizada';
      case EstadoObra.pausada:
        return 'Pausada';
    }
  }

  static EstadoObra fromString(String val) {
    switch (val) {
      case 'enProgreso':
        return EstadoObra.enProgreso;
      case 'finalizada':
        return EstadoObra.finalizada;
      case 'pausada':
        return EstadoObra.pausada;
      case 'planificada':
      default:
        return EstadoObra.planificada;
    }
  }
}

class Obra {
  final String id;
  final String nombre;
  final String? clienteId;
  final String? clienteNombre;
  final String? ubicacion;
  final String? descripcion;
  final double presupuesto;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final EstadoObra estado;
  final List<String> sociosAsignados;

  const Obra({
    required this.id,
    required this.nombre,
    this.clienteId,
    this.clienteNombre,
    this.ubicacion,
    this.descripcion,
    this.presupuesto = 0.0,
    required this.fechaInicio,
    this.fechaFin,
    this.estado = EstadoObra.enProgreso,
    this.sociosAsignados = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'ubicacion': ubicacion,
    'descripcion': descripcion,
    'presupuesto': presupuesto,
    'fechaInicio': fechaInicio.toIso8601String(),
    'fechaFin': fechaFin?.toIso8601String(),
    'estado': estado.name,
    'sociosAsignados': sociosAsignados,
  };

  factory Obra.fromJson(Map<String, dynamic> json) => Obra(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    clienteId: json['clienteId'] as String?,
    clienteNombre: json['clienteNombre'] as String?,
    ubicacion: json['ubicacion'] as String?,
    descripcion: json['descripcion'] as String?,
    presupuesto: (json['presupuesto'] as num?)?.toDouble() ?? 0.0,
    fechaInicio: DateTime.parse(json['fechaInicio'] as String),
    fechaFin: json['fechaFin'] != null ? DateTime.parse(json['fechaFin'] as String) : null,
    estado: EstadoObraExt.fromString(json['estado'] as String? ?? 'enProgreso'),
    sociosAsignados: (json['sociosAsignados'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );

  Obra copyWith({
    String? id,
    String? nombre,
    String? clienteId,
    String? clienteNombre,
    String? ubicacion,
    String? descripcion,
    double? presupuesto,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    EstadoObra? estado,
    List<String>? sociosAsignados,
  }) => Obra(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    clienteId: clienteId ?? this.clienteId,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    ubicacion: ubicacion ?? this.ubicacion,
    descripcion: descripcion ?? this.descripcion,
    presupuesto: presupuesto ?? this.presupuesto,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    fechaFin: fechaFin ?? this.fechaFin,
    estado: estado ?? this.estado,
    sociosAsignados: sociosAsignados ?? this.sociosAsignados,
  );
}
