class Socio {
  final String id;
  final String nombre;
  final String? telefono;
  final int colorValue; // Color identificador en hex int

  const Socio({
    required this.id,
    required this.nombre,
    this.telefono,
    this.colorValue = 0xFFF59E0B, // Amber default
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'colorValue': colorValue,
  };

  factory Socio.fromJson(Map<String, dynamic> json) => Socio(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String?,
    colorValue: json['colorValue'] as int? ?? 0xFFF59E0B,
  );

  Socio copyWith({
    String? id,
    String? nombre,
    String? telefono,
    int? colorValue,
  }) => Socio(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    telefono: telefono ?? this.telefono,
    colorValue: colorValue ?? this.colorValue,
  );
}
