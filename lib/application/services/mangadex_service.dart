import '../interfaces/i_manga_service.dart';
import '../../domain/interfaces/i_mangadex_reporitory.dart';

import '../../domain/entities/manga_entity.dart';
import '../../domain/entities/genre_entity.dart';

/// Servicio MangaDex que implementa IMangaService
/// Maneja las peticiones específicas a mangadex.org
class MangaDexService implements IMangaService {
  final IMangaDexRepository _repository;

  MangaDexService(this._repository);

  @override
  String get serverName => 'MangaDex';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final response = await _repository.getManga(page - 1);
      final mangaData = response['data'] as List<dynamic>;
      return _formatMangaList(mangaData);
    } catch (e) {
      throw Exception('Error en MangaDexService getAllMangas: $e');
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    // Por ahora retornamos la lista normal hasta implementar búsqueda específica
    return await getAllMangas(page: page, limit: 20);
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      final mangaDetailResponse = await _repository.getMangaDetail(mangaId);
      final mangaChaptersResponse = await _repository.getChapters(mangaId);

      return _formatMangaDetail(
        mangaDetailResponse['data'] as Map<String, dynamic>,
        mangaChaptersResponse['data'] as List<dynamic>,
        mangaId,
      );
    } catch (e) {
      throw Exception('Error en MangaDexService getMangaDetail: $e');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      final response = await _repository.getChapterDetail(chapterId);
      
      final chapterHash = response['chapter']['hash'] as String;
      final chapterBaseUrl = response['baseUrl'] as String;
      final chapterImages = response['chapter']['data'] as List<dynamic>;
      
      final images = <String>[];
      for (final image in chapterImages) {
        final imageUrl = '$chapterBaseUrl/data/$chapterHash/$image';
        images.add(imageUrl);
      }
      
      return images;
    } catch (e) {
      throw Exception('Error en MangaDexService getChapterImages: $e');
    }
  }

  List<MangaEntity> _formatMangaList(List<dynamic> mangaData) {
    final mangas = <MangaEntity>[];

    for (int index = 0; index < mangaData.length; index++) {
      try {
        final item = mangaData[index] as Map<String, dynamic>;
        
        // Extraer título principal
        final title = _extractTitle(
          item['attributes']['title'] as Map<String, dynamic>?,
          item['attributes']['altTitles'] as List<dynamic>?,
        );

        // Extraer imagen de portada
        final linkImage = _extractCoverImage(item);

        // Crear objeto Manga
        final manga = MangaEntity(
          id: item['id'] as String,
          title: title,
          description: _extractDescription(
            item['attributes']['description'] as Map<String, dynamic>?,
          ),
          coverImageUrl: linkImage.isNotEmpty ? linkImage : null,
          authors: [], // Se poblará en getMangaDetail
          genres: _extractGenres(
            item['attributes']['tags'] as List<dynamic>?,
          ).map((g) => g.text).toList(),
          status: _translateStatus(
            item['attributes']['status'] as String? ?? '',
          ),
          year: item['attributes']['year'] as int?,
          serverSource: 'MangaDex',
        );

        mangas.add(manga);
      } catch (e) {
        print('Error procesando manga en índice $index: $e');
        continue;
      }
    }

    return mangas;
  }

  MangaEntity _formatMangaDetail(
    Map<String, dynamic> mangaDetailData,
    List<dynamic> chaptersData,
    String mangaId,
  ) {
    try {
      final linkImage = _extractCoverImage(mangaDetailData);
      
      return MangaEntity(
        id: mangaId,
        title: _extractTitle(
          mangaDetailData['attributes']['title'] as Map<String, dynamic>?,
          mangaDetailData['attributes']['altTitles'] as List<dynamic>?,
        ),
        description: _extractDescription(
          mangaDetailData['attributes']['description'] as Map<String, dynamic>?,
        ),
        coverImageUrl: linkImage.isNotEmpty ? linkImage : null,
        authors: [_extractAuthor(
          mangaDetailData['relationships'] as List<dynamic>?,
        )],
        genres: _extractGenres(
          mangaDetailData['attributes']['tags'] as List<dynamic>?,
        ).map((g) => g.text).toList(),
        status: _translateStatus(
          mangaDetailData['attributes']['status'] as String? ?? '',
        ),
        year: mangaDetailData['attributes']['year'] as int?,
        chapterCount: chaptersData.length,
        serverSource: 'MangaDex',
      );
    } catch (e) {
      print('Error formateando detalles del manga: $e');
      return MangaEntity(
        id: mangaId,
        title: 'Error al cargar',
        status: 'error',
        serverSource: 'MangaDex',
      );
    }
  }

  String _extractTitle(
    Map<String, dynamic>? titleObj,
    List<dynamic>? altTitles,
  ) {
    // Intentar obtener título en español primero
    if (titleObj != null) {
      if (titleObj['es'] != null) return titleObj['es'] as String;
      if (titleObj['es-la'] != null) return titleObj['es-la'] as String;
    }

    // Buscar en títulos alternativos
    if (altTitles != null) {
      for (final altTitle in altTitles) {
        final altTitleMap = altTitle as Map<String, dynamic>;
        if (altTitleMap['es'] != null) return altTitleMap['es'] as String;
        if (altTitleMap['es-la'] != null) return altTitleMap['es-la'] as String;
      }
    }

    // Si no hay español, usar inglés
    if (titleObj != null && titleObj['en'] != null) {
      return titleObj['en'] as String;
    }

    // Buscar inglés en títulos alternativos
    if (altTitles != null) {
      for (final altTitle in altTitles) {
        final altTitleMap = altTitle as Map<String, dynamic>;
        if (altTitleMap['en'] != null) return altTitleMap['en'] as String;
      }
    }

    // Como último recurso, usar el primer título disponible
    if (titleObj != null && titleObj.isNotEmpty) {
      final firstKey = titleObj.keys.first;
      return titleObj[firstKey] as String;
    }

    return 'Título no disponible';
  }

  String _extractCoverImage(Map<String, dynamic> item) {
    try {
      final relationships = item['relationships'] as List<dynamic>?;
      if (relationships == null) return '';

      // Buscar el cover_art en las relaciones
      final coverArt = relationships.firstWhere(
        (rel) => (rel as Map<String, dynamic>)['type'] == 'cover_art',
        orElse: () => null,
      );

      if (coverArt != null) {
        final coverArtMap = coverArt as Map<String, dynamic>;
        final fileName = coverArtMap['attributes']?['fileName'] as String?;
        if (fileName != null) {
          return 'https://uploads.mangadex.org/covers/${item['id']}/$fileName.256.jpg';
        }
      }

      return '';
    } catch (e) {
      print('Error extrayendo imagen de portada: $e');
      return '';
    }
  }

  String _translateStatus(String status) {
    const statusMap = {
      'ongoing': 'En emisión',
      'completed': 'Completado',
      'hiatus': 'En pausa',
      'cancelled': 'Cancelado',
    };

    return statusMap[status] ?? status;
  }

  String _extractDescription(Map<String, dynamic>? descriptionObj) {
    if (descriptionObj == null) return 'Descripción no disponible';

    // Preferir descripción en español
    if (descriptionObj['es'] != null) return descriptionObj['es'] as String;
    if (descriptionObj['es-la'] != null) return descriptionObj['es-la'] as String;

    // Si no hay español, usar inglés
    if (descriptionObj['en'] != null) return descriptionObj['en'] as String;

    // Usar la primera descripción disponible
    if (descriptionObj.isNotEmpty) {
      final firstKey = descriptionObj.keys.first;
      return descriptionObj[firstKey] as String;
    }

    return 'Descripción no disponible';
  }

  List<GenreEntity> _extractGenres(List<dynamic>? tags) {
    if (tags == null) return [];

    final genres = <GenreEntity>[];

    // Filtrar solo los tags de género
    final genreTags = tags.where((tag) {
      final tagMap = tag as Map<String, dynamic>;
      final group = tagMap['attributes']['group'] as String;
      return group == 'genre' || group == 'theme';
    }).toList();

    for (final tag in genreTags) {
      final tagMap = tag as Map<String, dynamic>;
      final genreName = tagMap['attributes']['name']['en'] as String;
      final genreHref = 'https://MangaDex.org/search?includedTags=${tagMap['id']}';
      genres.add(GenreEntity(text: genreName, href: genreHref));
    }

    return genres;
  }

  String _extractAuthor(List<dynamic>? relationships) {
    if (relationships == null) return 'Autor desconocido';

    try {
      // Buscar autor en las relaciones
      final authorRelation = relationships.firstWhere(
        (rel) {
          final relMap = rel as Map<String, dynamic>;
          return relMap['type'] == 'author' && relMap['attributes']?['name'] != null;
        },
        orElse: () => null,
      );

      if (authorRelation != null) {
        final authorMap = authorRelation as Map<String, dynamic>;
        return authorMap['attributes']['name'] as String;
      }

      // Si no hay autor, buscar artista
      final artistRelation = relationships.firstWhere(
        (rel) {
          final relMap = rel as Map<String, dynamic>;
          return relMap['type'] == 'artist' && relMap['attributes']?['name'] != null;
        },
        orElse: () => null,
      );

      if (artistRelation != null) {
        final artistMap = artistRelation as Map<String, dynamic>;
        return artistMap['attributes']['name'] as String;
      }

      return 'Autor desconocido';
    } catch (e) {
      print('Error extrayendo autor: $e');
      return 'Autor desconocido';
    }
  }
}