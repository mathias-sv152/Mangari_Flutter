/// Entidad de dominio para representar un tag/filtro
class TagEntity {
  final String name;
  final String value;
  final TypeTagEntity type;

  TagEntity({
    required this.name,
    required this.value,
    required this.type,
  });

  factory TagEntity.fromJson(Map<String, String> json) {
    return TagEntity(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
      type: _parseTypeTag(json['type'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'type': _typeTagToString(type),
    };
  }

  static TypeTagEntity _parseTypeTag(String type) {
    switch (type.toLowerCase()) {
      case 'tipo':
        return TypeTagEntity.tipo;
      case 'estado':
        return TypeTagEntity.estado;
      case 'genero':
        return TypeTagEntity.genero;
      case 'order_dir':
        return TypeTagEntity.orderDir;
      case 'order_by':
        return TypeTagEntity.orderBy;
      default:
        return TypeTagEntity.genero;
    }
  }

  static String _typeTagToString(TypeTagEntity type) {
    switch (type) {
      case TypeTagEntity.tipo:
        return 'tipo';
      case TypeTagEntity.estado:
        return 'estado';
      case TypeTagEntity.genero:
        return 'genero';
      case TypeTagEntity.orderDir:
        return 'order_dir';
      case TypeTagEntity.orderBy:
        return 'order_by';
    }
  }
}

/// Tipos de tags disponibles
enum TypeTagEntity {
  tipo,
  estado,
  genero,
  orderDir,
  orderBy,
}

/// Tipos de filtros disponibles
enum FilterTypeEntity {
  radio,
  checkbox,
  dropdown,
}

/// Grupo de filtros
class FilterGroupEntity {
  final String key;
  final String title;
  final FilterTypeEntity filterType;
  final List<TagEntity> options;
  final String? dependsOn;

  FilterGroupEntity({
    required this.key,
    required this.title,
    required this.filterType,
    required this.options,
    this.dependsOn,
  });

  @override
  String toString() {
    return 'FilterGroupEntity(key: $key, title: $title, optionsCount: ${options.length})';
  }
}
