import 'package:mangari/domain/entities/manga_entity.dart';

/// Data Transfer Object para Manga de MangaDex
class MangaDexMangaDto {
  final String id;
  final Map<String, dynamic> attributes;
  final List<dynamic> relationships;

  MangaDexMangaDto({
    required this.id,
    required this.attributes,
    required this.relationships,
  });

  /// Convierte un JSON de MangaDex a MangaDexMangaDto
  factory MangaDexMangaDto.fromJson(Map<String, dynamic> json) {
    return MangaDexMangaDto(
      id: json['id'] ?? '',
      attributes: json['attributes'] ?? {},
      relationships: json['relationships'] ?? [],
    );
  }

  /// Convierte MangaDexMangaDto a MangaEntity (Domain Entity)
  MangaEntity toEntity() {
    // Extraer título en español o inglés como fallback
    final titles = attributes['title'] as Map<String, dynamic>? ?? {};
    String title = titles['es'] ?? titles['en'] ?? titles.values.first ?? 'Sin título';

    // Extraer descripción en español o inglés como fallback
    final descriptions = attributes['description'] as Map<String, dynamic>? ?? {};
    String? description = descriptions['es'] ?? descriptions['en'];

    // Extraer géneros
    List<String> genres = [];
    for (var relationship in relationships) {
      if (relationship['type'] == 'tag') {
        final tagName = relationship['attributes']?['name'];
        if (tagName != null && tagName['en'] != null) {
          genres.add(tagName['en']);
        }
      }
    }

    // Extraer autores
    List<String> authors = [];
    for (var relationship in relationships) {
      if (relationship['type'] == 'author') {
        final authorName = relationship['attributes']?['name'];
        if (authorName != null) {
          authors.add(authorName);
        }
      }
    }

    // Construir URL de imagen de portada
    String? coverImageUrl;
    for (var relationship in relationships) {
      if (relationship['type'] == 'cover_art') {
        final fileName = relationship['attributes']?['fileName'];
        if (fileName != null) {
          coverImageUrl = 'https://uploads.mangadex.org/covers/$id/$fileName.256.jpg';
        }
        break;
      }
    }

    return MangaEntity(
      id: id,
      title: title,
      description: description,
      coverImageUrl: coverImageUrl,
      authors: authors,
      genres: genres,
      status: _mapStatus(attributes['status']),
      originalLanguage: attributes['originalLanguage'],
      availableLanguages: List<String>.from(attributes['availableTranslatedLanguages'] ?? []),
      year: attributes['year'],
      rating: _parseRating(attributes['rating']),
      chapterCount: attributes['lastChapter'] != null 
          ? int.tryParse(attributes['lastChapter'].toString()) 
          : null,
      lastUpdated: _parseDateTime(attributes['updatedAt']),
      serverSource: 'mangadex',
    );
  }

  /// Mapea el estado de MangaDex al formato interno
  String _mapStatus(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'ongoing':
        return 'ongoing';
      case 'completed':
        return 'completed';
      case 'hiatus':
        return 'hiatus';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'unknown';
    }
  }

  /// Parsea el rating de MangaDex
  double? _parseRating(dynamic rating) {
    if (rating == null) return null;
    if (rating is double) return rating;
    if (rating is int) return rating.toDouble();
    if (rating is String) return double.tryParse(rating);
    return null;
  }

  /// Parsea la fecha de MangaDex
  DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is String) {
      return DateTime.tryParse(dateTime);
    }
    return null;
  }
}