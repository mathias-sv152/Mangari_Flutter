import 'package:mangari/domain/entities/genre_entity.dart';

/// Entidad que representa un manga guardado en la biblioteca local
class SavedMangaEntity {
  final int? id; // ID local en la base de datos
  final String mangaId; // ID del manga en el servidor
  final String title;
  final String linkImage;
  final String link;
  final String bookType;
  final String demography;
  final String serverName; // Nombre del servidor (TMO, MangaDex, etc.)
  final String serverId; // ID del servidor
  final String category; // Categoría/Tab donde está guardado
  final String description;
  final List<GenreEntity> genres;
  final String author;
  final String status;

  // Progreso de lectura
  final String? lastReadChapter; // Último capítulo leído
  final String? lastReadEditorial; // Editorial que se visualizó
  final int? lastReadPage; // Página exacta donde se quedó

  // Metadatos
  final DateTime savedAt; // Fecha de guardado
  final DateTime? lastReadAt; // Última vez que se leyó

  const SavedMangaEntity({
    this.id,
    required this.mangaId,
    required this.title,
    required this.linkImage,
    required this.link,
    required this.bookType,
    required this.demography,
    required this.serverName,
    required this.serverId,
    required this.category,
    this.description = 'Descripción no disponible',
    this.genres = const [],
    this.author = 'Autor desconocido',
    this.status = 'Estado desconocido',
    this.lastReadChapter,
    this.lastReadEditorial,
    this.lastReadPage,
    required this.savedAt,
    this.lastReadAt,
  });

  SavedMangaEntity copyWith({
    int? id,
    String? mangaId,
    String? title,
    String? linkImage,
    String? link,
    String? bookType,
    String? demography,
    String? serverName,
    String? serverId,
    String? category,
    String? description,
    List<GenreEntity>? genres,
    String? author,
    String? status,
    String? lastReadChapter,
    String? lastReadEditorial,
    int? lastReadPage,
    DateTime? savedAt,
    DateTime? lastReadAt,
  }) {
    return SavedMangaEntity(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      linkImage: linkImage ?? this.linkImage,
      link: link ?? this.link,
      bookType: bookType ?? this.bookType,
      demography: demography ?? this.demography,
      serverName: serverName ?? this.serverName,
      serverId: serverId ?? this.serverId,
      category: category ?? this.category,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      author: author ?? this.author,
      status: status ?? this.status,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      lastReadEditorial: lastReadEditorial ?? this.lastReadEditorial,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      savedAt: savedAt ?? this.savedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  /// Convierte la entidad a un Map para guardar en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'title': title,
      'link_image': linkImage,
      'link': link,
      'book_type': bookType,
      'demography': demography,
      'server_name': serverName,
      'server_id': serverId,
      'category': category,
      'description': description,
      'genres': genres.map((g) => g.text).join(','),
      'author': author,
      'status': status,
      'last_read_chapter': lastReadChapter,
      'last_read_editorial': lastReadEditorial,
      'last_read_page': lastReadPage,
      'saved_at': savedAt.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }

  /// Crea una entidad desde un Map de la base de datos
  factory SavedMangaEntity.fromMap(Map<String, dynamic> map) {
    return SavedMangaEntity(
      id: map['id'] as int?,
      mangaId: map['manga_id'] as String,
      title: map['title'] as String,
      linkImage: map['link_image'] as String,
      link: map['link'] as String,
      bookType: map['book_type'] as String,
      demography: map['demography'] as String,
      serverName: map['server_name'] as String,
      serverId: map['server_id'] as String,
      category: map['category'] as String,
      description: map['description'] as String? ?? 'Descripción no disponible',
      genres:
          (map['genres'] as String?)
              ?.split(',')
              .where((g) => g.isNotEmpty)
              .map((g) => GenreEntity(text: g, href: ''))
              .toList() ??
          [],
      author: map['author'] as String? ?? 'Autor desconocido',
      status: map['status'] as String? ?? 'Estado desconocido',
      lastReadChapter: map['last_read_chapter'] as String?,
      lastReadEditorial: map['last_read_editorial'] as String?,
      lastReadPage: map['last_read_page'] as int?,
      savedAt: DateTime.parse(map['saved_at'] as String),
      lastReadAt:
          map['last_read_at'] != null
              ? DateTime.parse(map['last_read_at'] as String)
              : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedMangaEntity &&
          runtimeType == other.runtimeType &&
          mangaId == other.mangaId &&
          serverId == other.serverId;

  @override
  int get hashCode => mangaId.hashCode ^ serverId.hashCode;

  @override
  String toString() =>
      'SavedMangaEntity(title: $title, mangaId: $mangaId, server: $serverName, category: $category)';
}
