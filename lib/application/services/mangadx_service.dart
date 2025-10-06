import '../../domain/interfaces/manga_interfaces.dart';
import '../../domain/entities/manga_detail_entity.dart';
import '../../domain/entities/chapter_view_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/editorial_entity.dart';
import '../../domain/entities/genre_entity.dart';

class MangaDxService implements IMangaService {
  final IMangaRepository _repository;

  MangaDxService(this._repository);

  // Propiedades para compatibilidad con IServersRepositoryV2
  String get serverName => 'MangaDx';
  bool get isActive => true;

  @override
  Future<List<MangaDetailEntity>> getManga(int page) async {
    try {
      final response = await _repository.getManga(page - 1);
      final mangaData = response['data'] as List<dynamic>;
      return _formatMangaList(mangaData);
    } catch (e) {
      throw Exception('Error en MangaDexService getManga: $e');
    }
  }

  List<MangaDetailEntity> _formatMangaList(List<dynamic> mangaData) {
    final mangas = <MangaDetailEntity>[];

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

        // Crear link del manga
        final link = 'https://mangadex.org/title/${item['id']}';

        // Determinar el tipo de libro
        final bookType = _extractBookType(
          item['attributes']['tags'] as List<dynamic>?,
        );

        // Extraer demografía
        final demography = 
            (item['attributes']['publicationDemographic'] as String?) ?? 'N/A';

        // Crear objeto Manga
        final manga = MangaDetailEntity(
          title: title,
          linkImage: linkImage,
          link: link,
          bookType: bookType,
          demography: demography,
          id: item['id'] as String,
          service: 'mangadex',
          referer: 'https://mangadex.org/',
          status: _translateStatus(
            item['attributes']['status'] as String? ?? '',
          ),
          description: _extractDescription(
            item['attributes']['description'] as Map<String, dynamic>?,
          ),
          genres: _extractGenres(
            item['attributes']['tags'] as List<dynamic>?,
          ),
          source: item['attributes']['year'] != null
              ? 'mangadex (${item['attributes']['year']})'
              : 'mangadex',
        );

        mangas.add(manga);
      } catch (e) {
        print('Error procesando manga en índice $index: $e');
        continue;
      }
    }

    return mangas;
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

  String _extractBookType(List<dynamic>? tags) {
    if (tags == null) return 'Manga';

    // Buscar tags que indiquen el formato
    final formatTags = tags.where((tag) {
      final tagMap = tag as Map<String, dynamic>;
      return tagMap['attributes']['group'] == 'format';
    }).toList();

    for (final tag in formatTags) {
      final tagMap = tag as Map<String, dynamic>;
      final tagName = (tagMap['attributes']['name']['en'] as String).toLowerCase();
      if (tagName.contains('manga')) return 'Manga';
      if (tagName.contains('manhwa')) return 'Manhwa';
      if (tagName.contains('manhua')) return 'Manhua';
      if (tagName.contains('web comic')) return 'Webtoon';
      if (tagName.contains('4-koma')) return '4-Koma';
    }

    return 'Manga'; // Por defecto
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
      final genreHref = 'https://mangadex.org/search?includedTags=${tagMap['id']}';
      genres.add(GenreEntity(text: genreName, href: genreHref));
    }

    return genres;
  }

  @override
  Future<MangaDetailEntity> getMangaDetail(MangaDetailEntity manga) async {
    try {
      final mangaDetailResponse = await _repository.getMangaDetail(manga.id);
      final mangaChaptersResponse = await _repository.getChapters(manga.id);

      return _formatMangaDetail(
        mangaDetailResponse['data'] as Map<String, dynamic>,
        mangaChaptersResponse['data'] as List<dynamic>,
        manga,
      );
    } catch (e) {
      throw Exception('Error en MangaDexService getMangaDetail: $e');
    }
  }

  MangaDetailEntity _formatMangaDetail(
    Map<String, dynamic> mangaDetailData,
    List<dynamic> chaptersData,
    MangaDetailEntity originalManga,
  ) {
    try {
      return originalManga.copyWith(
        title: _extractTitle(
          mangaDetailData['attributes']['title'] as Map<String, dynamic>?,
          mangaDetailData['attributes']['altTitles'] as List<dynamic>?,
        ),
        description: _extractDescription(
          mangaDetailData['attributes']['description'] as Map<String, dynamic>?,
        ),
        genres: _extractGenres(
          mangaDetailData['attributes']['tags'] as List<dynamic>?,
        ),
        status: _translateStatus(
          mangaDetailData['attributes']['status'] as String? ?? '',
        ),
        author: _extractAuthor(
          mangaDetailData['relationships'] as List<dynamic>?,
        ),
        source: mangaDetailData['attributes']['year'] != null
            ? '${originalManga.service} (${mangaDetailData['attributes']['year']})'
            : originalManga.service,
        bookType: _extractBookType(
          mangaDetailData['attributes']['tags'] as List<dynamic>?,
        ),
        chapters: _formatChaptersList(chaptersData),
      );
    } catch (e) {
      print('Error formateando detalles del manga: $e');
      return originalManga;
    }
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

  List<ChapterEntity> _formatChaptersList(List<dynamic> chaptersData) {
    try {
      final chapters = <ChapterEntity>[];
      final chapterGroups = <String, List<Map<String, dynamic>>>{};

      // Agrupar capítulos por número
      for (final chapterData in chaptersData) {
        final chapterMap = chapterData as Map<String, dynamic>;
        final chapterNumber = chapterMap['attributes']['chapter'] as String? ?? '0';
        final volume = chapterMap['attributes']['volume'] as String? ?? '';

        final chapterKey = volume.isNotEmpty 
            ? 'Vol.$volume Ch.$chapterNumber'
            : 'Ch.$chapterNumber';

        chapterGroups.putIfAbsent(chapterKey, () => []);
        chapterGroups[chapterKey]!.add(chapterMap);
      }

      // Convertir grupos en objetos Chapter
      chapterGroups.forEach((chapterKey, chapterGroup) {
        final firstChapter = chapterGroup.first;

        // Crear título del capítulo
        var chapterTitle = chapterKey;
        final title = firstChapter['attributes']['title'] as String?;
        if (title != null && title.isNotEmpty) {
          chapterTitle += ' - $title';
        }

        // Crear editoriales para cada grupo de traducción
        final editorials = <EditorialEntity>[];

        for (final chapterData in chapterGroup) {
          final relationships = chapterData['relationships'] as List<dynamic>? ?? [];
          
          // Extraer grupos de traducción
          final scanlationGroups = relationships.where((rel) {
            final relMap = rel as Map<String, dynamic>;
            return relMap['type'] == 'scanlation_group';
          }).toList();

          if (scanlationGroups.isNotEmpty) {
            for (final group in scanlationGroups) {
              final groupMap = group as Map<String, dynamic>;
              final editorialName = groupMap['attributes']?['name'] as String? ?? 'Desconocido';
              final editorialLink = chapterData['id'] as String;
              final dateRelease = _formatDate(
                chapterData['attributes']['publishAt'] as String?,
              );

              editorials.add(EditorialEntity(
                editorialName: editorialName,
                editorialLink: editorialLink,
                dateRelease: dateRelease,
              ));
            }
          } else {
            // Si no hay grupos de traducción, crear una editorial genérica
            editorials.add(EditorialEntity(
              editorialName: 'MangaDex',
              editorialLink: 'https://mangadex.org/chapter/${chapterData['id']}',
              dateRelease: _formatDate(
                chapterData['attributes']['publishAt'] as String?,
              ),
            ));
          }
        }

        // Crear el capítulo
        final chapter = ChapterEntity(
          numAndTitleCap: chapterTitle,
          dateRelease: _formatDate(
            firstChapter['attributes']['publishAt'] as String?,
          ),
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
    final match = RegExp(r'Ch\.(\d+(?:\.\d+)?)').firstMatch(title);
    return match != null ? double.tryParse(match.group(1)!) ?? 0 : 0;
  }

  String _formatDate(String? dateString) {
    try {
      if (dateString == null || dateString.isEmpty) return 'Fecha desconocida';

      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      print('Error formateando fecha: $e');
      return 'Fecha desconocida';
    }
  }

  @override
  Future<List<String>> getChapterImages(ChapterViewEntity chapter) async {
    try {
      final response = await _repository.getChapterDetail(chapter.editorialLink);
      
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

  /// Método para obtener imágenes de capítulo usando ID de capítulo (String)
  /// Compatible con la interfaz IServersRepositoryV2
  Future<List<String>> getChapterImagesById(String chapterId) async {
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
      throw Exception('Error al obtener imágenes del capítulo por ID: $e');
    }
  }
}