class Cliente {
  final String id;
  final String nombre;
  final String? telefono;
  final String? direccion;
  final String? notas;

  const Cliente({
    required this.id,
    required this.nombre,
    this.telefono,
    this.direccion,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'direccion': direccion,
    'notas': notas,
  };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String?,
    direccion: json['direccion'] as String?,
    notas: json['notas'] as String?,
  );

  Cliente copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? direccion,
    String? notas,
  }) => Cliente(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    direccion: direccion ?? this.direccion,
    notas: notas ?? this.notas,
  );
}
