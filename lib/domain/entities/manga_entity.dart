import 'package:mangari/domain/entities/chapter_entity.dart';

/// Entidad de dominio para Manga
/// Representa un manga en el sistema
class MangaEntity {
  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final List<String> authors;
  final List<String> genres;
  final String status; // ongoing, completed, hiatus, cancelled
  final String? originalLanguage;
  final List<String> availableLanguages;
  final int? year;
  final double? rating;
  final int? chapterCount;
  final List<ChapterEntity> chapters;
  final DateTime? lastUpdated;
  final String serverSource; // mangadex, tmo, etc.
  final String referer;

  MangaEntity({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.authors = const [],
    this.genres = const [],
    required this.status,
    this.originalLanguage,
    this.availableLanguages = const [],
    this.year,
    this.rating,
    this.chapterCount,
    this.chapters = const [],
    this.lastUpdated,
    required this.serverSource,
    required this.referer,
  });

  @override
  String toString() {
    return 'MangaEntity(id: $id, title: $title, serverSource: $serverSource)';
  }

  /// Crea una copia del manga con campos actualizados
  MangaEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? authors,
    List<String>? genres,
    String? status,
    String? originalLanguage,
    List<String>? availableLanguages,
    int? year,
    double? rating,
    int? chapterCount,
    List<ChapterEntity>? chapters,
    DateTime? lastUpdated,
    String? serverSource,
    String? referer,
  }) {
    return MangaEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      authors: authors ?? this.authors,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      chapterCount: chapterCount ?? this.chapterCount,
      chapters: chapters ?? this.chapters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      serverSource: serverSource ?? this.serverSource,
      referer: referer ?? this.referer,
    );
  }
}
