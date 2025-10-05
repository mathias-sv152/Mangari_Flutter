import 'chapter_entity.dart';
import 'genre_entity.dart';

class MangaDetailEntity {
  final String title;
  final String linkImage;
  final String link;
  final String bookType;
  final String demography;
  final String id;
  final String service;
  final String? referer;
  final bool isFavorite;

  // Detalles adicionales
  final String description;
  final List<GenreEntity> genres;
  final List<ChapterEntity> chapters;
  final String author;
  final String status;
  final String source;

  const MangaDetailEntity({
    required this.title,
    required this.linkImage,
    required this.link,
    required this.bookType,
    required this.demography,
    required this.id,
    required this.service,
    this.referer,
    this.isFavorite = false,
    this.description = 'Descripción no disponible',
    this.genres = const [],
    this.chapters = const [],
    this.author = 'Autor desconocido',
    this.status = 'Estado desconocido',
    this.source = 'Fuente desconocida',
  });

  MangaDetailEntity copyWith({
    String? title,
    String? linkImage,
    String? link,
    String? bookType,
    String? demography,
    String? id,
    String? service,
    String? referer,
    bool? isFavorite,
    String? description,
    List<GenreEntity>? genres,
    List<ChapterEntity>? chapters,
    String? author,
    String? status,
    String? source,
  }) {
    return MangaDetailEntity(
      title: title ?? this.title,
      linkImage: linkImage ?? this.linkImage,
      link: link ?? this.link,
      bookType: bookType ?? this.bookType,
      demography: demography ?? this.demography,
      id: id ?? this.id,
      service: service ?? this.service,
      referer: referer ?? this.referer,
      isFavorite: isFavorite ?? this.isFavorite,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      chapters: chapters ?? this.chapters,
      author: author ?? this.author,
      status: status ?? this.status,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaDetailEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          service == other.service;

  @override
  int get hashCode => id.hashCode ^ service.hashCode;

  @override
  String toString() =>
      'MangaDetailEntity(title: $title, id: $id, service: $service)';
}