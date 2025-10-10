import 'package:mangari/domain/entities/filter_entity.dart';

import '../interfaces/i_manga_service.dart';
import '../../domain/interfaces/i_mangadex_reporitory.dart';

import '../../domain/entities/manga_entity.dart';
import '../../domain/entities/genre_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/editorial_entity.dart';

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
      final formatdetailmanga = _formatMangaDetail(
        mangaDetailResponse['data'] as Map<String, dynamic>,
        mangaChaptersResponse['data'] as List<dynamic>,
        mangaId,
      );
      print(formatdetailmanga);
      return formatdetailmanga;
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
          genres:
              _extractGenres(
                item['attributes']['tags'] as List<dynamic>?,
              ).map((g) => g.text).toList(),
          status: _translateStatus(
            item['attributes']['status'] as String? ?? '',
          ),
          year: item['attributes']['year'] as int?,
          serverSource: 'MangaDex',
          referer: 'https://mangadex.org',
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
      print('🔍 MangaDex _formatMangaDetail - Manga ID: $mangaId');
      print('🔍 MangaDex _formatMangaDetail - Link Image extraída: $linkImage');

      return MangaEntity(
        id: mangaId,
        title: _extractTitle(
          mangaDetailData['attributes']['title'] as Map<String, dynamic>?,
          mangaDetailData['attributes']['altTitles'] as List<dynamic>?,
        ),
        description: _extractDescription(
          mangaDetailData['attributes']['description'] as Map<String, dynamic>?,
        ),
        coverImageUrl: linkImage,
        authors: [
          _extractAuthor(mangaDetailData['relationships'] as List<dynamic>?),
        ],
        genres:
            _extractGenres(
              mangaDetailData['attributes']['tags'] as List<dynamic>?,
            ).map((g) => g.text).toList(),
        status: _translateStatus(
          mangaDetailData['attributes']['status'] as String? ?? '',
        ),
        year: mangaDetailData['attributes']['year'] as int?,
        chapterCount: chaptersData.length,
        chapters: _formatChaptersList(chaptersData),
        serverSource: 'MangaDex',
        referer: 'https://mangadex.org',
      );
    } catch (e) {
      print('Error formateando detalles del manga: $e');
      return MangaEntity(
        id: mangaId,
        title: 'Error al cargar',
        status: 'error',
        serverSource: 'MangaDex',
        referer: 'https://mangadex.org',
      );
    }
  }

  List<ChapterEntity> _formatChaptersList(List<dynamic> chaptersData) {
    try {
      final chapters = <ChapterEntity>[];

      // Agrupar capítulos por número de capítulo
      final chapterGroups = <String, List<Map<String, dynamic>>>{};

      for (final chapterData in chaptersData) {
        final chapterMap = chapterData as Map<String, dynamic>;
        final attributes = chapterMap['attributes'] as Map<String, dynamic>;

        final chapterNumber = attributes['chapter'] as String? ?? '0';
        final volume = attributes['volume'] as String? ?? '';

        // Crear una clave única para el capítulo
        final chapterKey =
            volume.isNotEmpty
                ? 'Vol.$volume Ch.$chapterNumber'
                : 'Ch.$chapterNumber';

        if (!chapterGroups.containsKey(chapterKey)) {
          chapterGroups[chapterKey] = [];
        }

        chapterGroups[chapterKey]!.add(chapterMap);
      }

      // Convertir grupos en objetos ChapterEntity
      chapterGroups.forEach((chapterKey, chapterGroup) {
        final firstChapter = chapterGroup[0];
        final firstAttributes =
            firstChapter['attributes'] as Map<String, dynamic>;

        // Crear título del capítulo
        String chapterTitle = chapterKey;
        final chapterTitleText = firstAttributes['title'] as String?;
        if (chapterTitleText != null && chapterTitleText.isNotEmpty) {
          chapterTitle += ' - $chapterTitleText';
        }

        // Crear editoriales para cada grupo de traducción
        final editorials = <EditorialEntity>[];

        for (final chapterMap in chapterGroup) {
          final relationships = chapterMap['relationships'] as List<dynamic>?;

          // Extraer grupos de traducción
          final scanlationGroups =
              relationships?.where((rel) {
                final relMap = rel as Map<String, dynamic>;
                return relMap['type'] == 'scanlation_group';
              }).toList() ??
              [];

          if (scanlationGroups.isNotEmpty) {
            for (final group in scanlationGroups) {
              final groupMap = group as Map<String, dynamic>;
              final attributes =
                  groupMap['attributes'] as Map<String, dynamic>?;
              final editorialName =
                  attributes?['name'] as String? ?? 'Desconocido';

              // Crear link para leer el capítulo
              final editorialLink = chapterMap['id'] as String;

              // Fecha de publicación
              final chapterAttributes =
                  chapterMap['attributes'] as Map<String, dynamic>;
              final dateRelease = _formatDate(
                chapterAttributes['publishAt'] as String?,
              );

              editorials.add(
                EditorialEntity(
                  editorialName: editorialName,
                  editorialLink: editorialLink,
                  dateRelease: dateRelease,
                ),
              );
            }
          } else {
            // Si no hay grupos de traducción, crear una editorial genérica
            final chapterAttributes =
                chapterMap['attributes'] as Map<String, dynamic>;
            editorials.add(
              EditorialEntity(
                editorialName: 'MangaDex',
                editorialLink: chapterMap['id'] as String,
                dateRelease: _formatDate(
                  chapterAttributes['publishAt'] as String?,
                ),
              ),
            );
          }
        }

        // Crear el capítulo
        final chapter = ChapterEntity(
          numAndTitleCap: chapterTitle,
          dateRelease: _formatDate(firstAttributes['publishAt'] as String?),
          editorials: editorials,
        );

        chapters.add(chapter);
      });

      // Ordenar capítulos por número (descendente - más reciente primero)
      chapters.sort((a, b) {
        final numA = _extractChapterNumber(a.numAndTitleCap);
        final numB = _extractChapterNumber(b.numAndTitleCap);
        return numB.compareTo(numA);
      });

      return chapters;
    } catch (e) {
      print('Error formateando lista de capítulos: $e');
      return [];
    }
  }

  double _extractChapterNumber(String title) {
    // Extraer el número de capítulo del título
    final match = RegExp(r'Ch\.(\d+(?:\.\d+)?)').firstMatch(title);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Fecha desconocida';
    }

    try {
      final date = DateTime.parse(dateString);

      // Formatear fecha como "dd/MM/yyyy"
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    } catch (e) {
      print('Error formateando fecha: $e');
      return 'Fecha desconocida';
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
      print('🔍 _extractCoverImage - Manga ID: ${item['id']}');
      final relationships = item['relationships'] as List<dynamic>?;
      print(
        '🔍 _extractCoverImage - Relationships: ${relationships?.length ?? 0}',
      );

      if (relationships == null) {
        print('❌ _extractCoverImage - No hay relationships');
        return '';
      }

      // Buscar el cover_art en las relaciones
      final coverArt = relationships.firstWhere(
        (rel) => (rel as Map<String, dynamic>)['type'] == 'cover_art',
        orElse: () => null,
      );

      if (coverArt != null) {
        final coverArtMap = coverArt as Map<String, dynamic>;
        final fileName = coverArtMap['attributes']?['fileName'] as String?;
        print('🔍 _extractCoverImage - fileName: $fileName');
        if (fileName != null) {
          final imageUrl =
              'https://uploads.mangadex.org/covers/${item['id']}/$fileName.256.jpg';
          print('✅ _extractCoverImage - URL generada: $imageUrl');
          return imageUrl;
        } else {
          print('❌ _extractCoverImage - fileName es null');
        }
      } else {
        print(
          '❌ _extractCoverImage - No se encontró cover_art en relationships',
        );
      }

      return '';
    } catch (e) {
      print('❌ Error extrayendo imagen de portada: $e');
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
    if (descriptionObj['es-la'] != null)
      return descriptionObj['es-la'] as String;

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
    final genreTags =
        tags.where((tag) {
          final tagMap = tag as Map<String, dynamic>;
          final group = tagMap['attributes']['group'] as String;
          return group == 'genre' || group == 'theme';
        }).toList();

    for (final tag in genreTags) {
      final tagMap = tag as Map<String, dynamic>;
      final genreName = tagMap['attributes']['name']['en'] as String;
      final genreHref =
          'https://MangaDex.org/search?includedTags=${tagMap['id']}';
      genres.add(GenreEntity(text: genreName, href: genreHref));
    }

    return genres;
  }

  String _extractAuthor(List<dynamic>? relationships) {
    if (relationships == null) return 'Autor desconocido';

    try {
      // Buscar autor en las relaciones
      final authorRelation = relationships.firstWhere((rel) {
        final relMap = rel as Map<String, dynamic>;
        return relMap['type'] == 'author' &&
            relMap['attributes']?['name'] != null;
      }, orElse: () => null);

      if (authorRelation != null) {
        final authorMap = authorRelation as Map<String, dynamic>;
        return authorMap['attributes']['name'] as String;
      }

      // Si no hay autor, buscar artista
      final artistRelation = relationships.firstWhere((rel) {
        final relMap = rel as Map<String, dynamic>;
        return relMap['type'] == 'artist' &&
            relMap['attributes']?['name'] != null;
      }, orElse: () => null);

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

  @override
  Future<List<FilterGroupEntity>> getFilters() async {
    // MangaDex no tiene filtros específicos
    return [];
  }

  @override
  Future<List<MangaEntity>> applyFilter(
    int page,
    Map<String, dynamic> selectedFilters,
  ) async {
    // MangaDex no tiene filtros específicos, retornamos la lista normal
    return await getAllMangas(page: page, limit: 20);
  }

  @override
  Map<String, dynamic> prepareFilterParams(
    Map<String, dynamic> selectedFilters,
  ) {
    // Mangadex no tiene filtros específicos
    return {};
  }
}
