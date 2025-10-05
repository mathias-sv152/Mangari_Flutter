/// Entidad de dominio para Server
/// Representa un servidor de manga con su servicio asociado
class ServerEntity {
  final String id;
  final String name;
  final String iconUrl;
  final String language;
  final String baseUrl;
  final bool isActive;
  final String? serviceName; // Nombre del servicio asociado

  ServerEntity({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.language,
    required this.baseUrl,
    required this.isActive,
    this.serviceName,
  });

  @override
  String toString() {
    return 'ServerEntity(id: $id, name: $name, isActive: $isActive)';
  }

  /// Crea una copia del servidor con campos actualizados
  ServerEntity copyWith({
    String? id,
    String? name,
    String? iconUrl,
    String? language,
    String? baseUrl,
    bool? isActive,
    String? serviceName,
  }) {
    return ServerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      language: language ?? this.language,
      baseUrl: baseUrl ?? this.baseUrl,
      isActive: isActive ?? this.isActive,
      serviceName: serviceName ?? this.serviceName,
    );
  }
}