import 'package:mangari/application/interfaces/i_manga_service.dart';
import 'package:mangari/domain/entities/filter_entity.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/entities/chapter_entity.dart';
import 'package:mangari/domain/entities/editorial_entity.dart';
import 'package:mangari/domain/interfaces/i_hitomi_repository.dart';

class HitomiService implements IMangaService {
  final IHitomiRepository _hitomiRepository;

  // Cache para almacenar las galerías ya obtenidas
  final Map<int, Map<String, dynamic>> _galleryCache = {};

  HitomiService({required IHitomiRepository hitomiRepository})
    : _hitomiRepository = hitomiRepository;

  @override
  String get serverName => 'Hitomi';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final galleries = await _hitomiRepository.getManga(page);
      final formattedList = _formatListManga(galleries);
      return formattedList;
    } catch (error) {
      print('Error en HitomiService getAllMangas: $error');
      return [];
    }
  }

  List<MangaEntity> _formatListManga(List<Map<String, dynamic>> galleries) {
    final mangas = <MangaEntity>[];
    const referer = 'https://hitomi.la/index-spanish.html';

    for (int index = 0; index < galleries.length; index++) {
      final gallery = galleries[index];
      if (gallery.containsKey('title') && gallery['title'] != null) {
        mangas.add(
          MangaEntity(
            id: gallery['id'].toString(),
            title: gallery['title'],
            coverImageUrl: gallery['linkImage'] ?? '',
            status: gallery['language'] ?? '',
            serverSource: 'hitomi',
            genres: gallery['type'] != null ? [gallery['type']] : [],
            referer: referer,
          ),
        );
      }
    }

    return mangas;
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      final id = int.parse(mangaId);

      // Obtener y almacenar en cache la galería
      Map<String, dynamic>? gallery = _galleryCache[id];

      if (gallery == null) {
        gallery = await _hitomiRepository.getGallery(id);
        if (gallery != null) {
          _galleryCache[id] = gallery;
          print('Gallery $id cached for future use');
        }
      } else {
        print('Gallery $id loaded from cache');
      }

      if (gallery == null) {
        print('No gallery data found, returning basic manga');
        return MangaEntity(
          id: mangaId,
          title: 'Gallery $mangaId',
          status: 'unknown',
          serverSource: 'hitomi',
          referer: 'https://hitomi.la',
        );
      }

      // Crear manga detallado con información básica
      final detailedManga = MangaEntity(
        id: mangaId,
        title: gallery['title'] ?? 'Gallery $mangaId',
        coverImageUrl: gallery['linkImage'] ?? '',
        status: gallery['language'] ?? 'unknown',
        serverSource: 'hitomi',
        referer: 'https://hitomi.la',
        authors: _extractArtists(gallery),
        genres: _extractTags(gallery),
        description: _buildDescription(gallery),
        chapters: [_createSingleChapter(gallery, mangaId)],
      );

      return detailedManga;
    } catch (error) {
      print('Error en HitomiService getMangaDetail: $error');
      rethrow;
    }
  }

  List<String> _extractArtists(Map<String, dynamic> gallery) {
    if (gallery.containsKey('artist') && gallery['artist'] is List) {
      final artists = <String>[];
      for (final artist in gallery['artist']) {
        if (artist is String) {
          artists.add(artist);
        } else if (artist is Map && artist.containsKey('artist')) {
          artists.add(artist['artist'].toString());
        }
      }
      return artists;
    }
    return [];
  }

  List<String> _extractTags(Map<String, dynamic> gallery) {
    if (gallery.containsKey('tags') && gallery['tags'] is List) {
      final tags = <String>[];
      for (final tag in gallery['tags']) {
        if (tag is String) {
          tags.add(tag);
        } else if (tag is Map) {
          final tagName = tag['tag'] ?? tag['name'] ?? '';
          if (tagName.isNotEmpty) {
            tags.add(tagName.toString());
          }
        }
      }
      return tags;
    }
    return [];
  }

  String? _buildDescription(Map<String, dynamic> gallery) {
    if (gallery.containsKey('japanese_title')) {
      return 'Título japonés: ${gallery['japanese_title']}';
    } else if (gallery.containsKey('language_localname')) {
      return 'Idioma: ${gallery['language_localname']}';
    }
    return null;
  }

  ChapterEntity _createSingleChapter(
    Map<String, dynamic> gallery,
    String mangaId,
  ) {
    // En Hitomi, cada galería es una obra completa
    final filesCount =
        gallery.containsKey('files') && gallery['files'] is List
            ? (gallery['files'] as List).length
            : 0;

    final chapterTitle = filesCount > 0 ? 'Leer ($filesCount páginas)' : 'Leer';

    // Crear una editorial que representa a Hitomi
    final editorial = EditorialEntity(
      editorialName: 'Hitomi.la',
      editorialLink: mangaId, // Usamos el ID de la galería
      dateRelease: gallery['date']?.toString() ?? 'N/A',
    );

    return ChapterEntity(
      numAndTitleCap: chapterTitle,
      dateRelease: gallery['date']?.toString() ?? 'N/A',
      editorials: [editorial],
    );
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      final galleryId = int.parse(chapterId);

      // Primero intentar obtener de cache
      Map<String, dynamic>? gallery = _galleryCache[galleryId];

      if (gallery == null) {
        print('Gallery $galleryId not in cache, fetching...');
        gallery = await _hitomiRepository.getGallery(galleryId);
        if (gallery != null) {
          _galleryCache[galleryId] = gallery;
        }
      } else {
        print('Gallery $galleryId loaded from cache for images');
      }

      if (gallery == null || !gallery.containsKey('files')) {
        print('No files found in gallery');
        return [];
      }

      // Obtener datos DINÁMICOS de gg.js (NO cachear - los valores cambian)
      // Los valores 'b' (timestamp), 'o' y los casos del switch son dinámicos
      final ggData = await _hitomiRepository.getGGData();
      if (ggData == null) {
        print('Failed to get GG data');
        return [];
      }

      // Construir URLs de las imágenes
      final images = <String>[];
      final files = gallery['files'] as List;

      for (final file in files) {
        if (file is Map &&
            file.containsKey('name') &&
            file.containsKey('hash')) {
          final fileMap = Map<String, dynamic>.from(file);
          final imageUrl = _buildHitomiImageUrl(galleryId, fileMap, ggData);
          if (imageUrl != null) {
            images.add(imageUrl);
          }
        }
      }

      print('Found ${images.length} images for gallery $galleryId');
      return images;
    } catch (error) {
      print('Error en HitomiService getChapterImages: $error');
      return [];
    }
  }

  String? _buildHitomiImageUrl(
    int galleryId,
    Map<String, dynamic> file,
    Map<String, dynamic> ggData,
  ) {
    try {
      final hash = file['hash'] as String;
      final hasAvif = file['hasavif'] == 1 || file['hasavif'] == true;
      final name = file['name'] as String;

      final extension = hasAvif ? 'avif' : name.split('.').last.toLowerCase();

      // Usar la función s de ggData para obtener el subdirectorio
      final sFunction = ggData['s'] as String Function(String);
      final basePath = ggData['b'] as String;

      // Construir el path completo: basePath + subdirectory + hash
      // Ejemplo: 1759953601/ + 864/ + hash
      final fullPath = basePath + sFunction(hash) + hash;

      // Calcular subdominio usando la función real de Hitomi
      final subdomain = _getHitomiSubdomain(hash, hasAvif, ggData);

      // Construir URL final
      final imageUrl =
          'https://$subdomain.gold-usergeneratedcontent.net/$fullPath.$extension';

      print('Built Hitomi image URL for $name: $imageUrl');
      return imageUrl;
    } catch (error) {
      print('Error building Hitomi image URL: $error');
      return null;
    }
  }

  String _getHitomiSubdomain(
    String hash,
    bool hasAvif,
    Map<String, dynamic> ggData,
  ) {
    try {
      // Lógica de subdomain_from_url del common.js de Hitomi
      // Para AVIF: 'a' + número, para otros: 'b' + número
      String retval = hasAvif ? 'a' : 'b';

      // Extraer los últimos 3 caracteres del hash siguiendo el patrón del regex JS:
      // var r = /\/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])/;
      // Grupos: m[1] = penúltimos 2 chars, m[2] = último char
      final match = RegExp(r'([0-9a-f]{2})([0-9a-f])$').firstMatch(hash);

      if (match == null) {
        print('⚠️ Hash does not match expected pattern: $hash');
        // Usar valor dinámico de gg.js para el fallback
        final o = ggData['o'] as int? ?? 1;
        return '$retval${o + 1}'; // Default dinámico basado en 'o'
      }

      // En el código JS: var g = parseInt(m[2]+m[1], 16)
      // m[1] = penúltimos 2 chars, m[2] = último char
      final secondToLastChars = match.group(1)!;
      final lastChar = match.group(2)!;
      final hexValue =
          lastChar + secondToLastChars; // Concatenar: último + penúltimos
      final g = int.parse(hexValue, radix: 16);

      // Obtener valores DINÁMICOS de gg.js
      final mFunction = ggData['m'] as int Function(int);
      final mResult = mFunction(g);
      final isInverted = ggData['isInverted'] as bool? ?? false;

      // Del common.js: retval = retval + (1 + gg.m(g))
      // La función m(g) puede comportarse de dos formas:
      //
      // MODO 1 - Normal (oInitial=0, oSwitch=1):
      //   - m(g) = 0 (default) → subdomain = 1 + 0 = 1 → a1/b1
      //   - m(g) = 1 (special) → subdomain = 1 + 1 = 2 → a2/b2
      //
      // MODO 2 - INVERTIDO (oInitial=1, oSwitch=0):
      //   - m(g) = 1 (default) → subdomain = 1 + 1 = 2 → a2/b2
      //   - m(g) = 0 (special) → subdomain = 1 + 0 = 1 → a1/b1
      final subdomainNumber = 1 + mResult;
      final subdomain = retval + subdomainNumber.toString();

      final behavior = isInverted ? 'INVERTED' : 'normal';
      print(
        '🌐 [$behavior] hash=${hash.substring(hash.length - 3)}, g=$g, m(g)=$mResult → $subdomain',
      );

      return subdomain;
    } catch (error) {
      print('❌ Error calculating Hitomi subdomain: $error');
      // Usar valor dinámico de gg.js para el fallback
      final o = ggData['o'] as int? ?? 1;
      return hasAvif ? 'a${o + 1}' : 'b${o + 1}'; // Fallback dinámico
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      print('🔍 Searching Hitomi for: "$query" (page $page)');
      
      // Usar el método de búsqueda del repositorio
      final galleries = await _hitomiRepository.searchManga(query, page);
      final formattedList = _formatListManga(galleries);
      
      print('✅ Found ${formattedList.length} results for "$query"');
      return formattedList;
    } catch (error) {
      print('Error en HitomiService searchManga: $error');
      return [];
    }
  }

  @override
  Future<List<FilterGroupEntity>> getFilters() async {
    // Retornar filtros de ordenamiento para Hitomi
    return [
      FilterGroupEntity(
        key: 'orderBy',
        title: 'Ordenar por',
        filterType: FilterTypeEntity.radio,
        options: [
          TagEntity(
            name: 'Fecha Añadida',
            value: 'date_added',
            type: TypeTagEntity.orderBy,
          ),
          TagEntity(
            name: 'Fecha Publicada',
            value: 'date_published',
            type: TypeTagEntity.orderBy,
          ),
          TagEntity(
            name: 'Popular: Hoy',
            value: 'popular_today',
            type: TypeTagEntity.orderBy,
          ),
          TagEntity(
            name: 'Popular: Semana',
            value: 'popular_week',
            type: TypeTagEntity.orderBy,
          ),
          TagEntity(
            name: 'Popular: Mes',
            value: 'popular_month',
            type: TypeTagEntity.orderBy,
          ),
          TagEntity(
            name: 'Popular: Año',
            value: 'popular_year',
            type: TypeTagEntity.orderBy,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<MangaEntity>> applyFilter(
    int page,
    Map<String, dynamic> selectedFilters,
  ) async {
    try {
      // Extraer parámetros de los filtros
      final filterParams = prepareFilterParams(selectedFilters);
      final searchText = selectedFilters['searchText'] as String? ?? '';
      final orderBy = filterParams['orderBy'] as String?;
      final orderByKey = filterParams['orderByKey'] as String?;

      print('🔍 Hitomi applyFilter:');
      print('  📝 Query: "$searchText"');
      print('  🔢 Page: $page');
      print('  📊 OrderBy: $orderBy, Key: $orderByKey');

      // Usar el método con filtros
      final galleries = await _hitomiRepository.searchMangaWithFilters(
        searchText,
        page,
        orderBy: orderBy,
        orderByKey: orderByKey,
      );

      final formattedList = _formatListManga(galleries);
      print('✅ Hitomi: Found ${formattedList.length} results');
      
      return formattedList;
    } catch (error) {
      print('❌ Error en HitomiService applyFilter: $error');
      return [];
    }
  }

  @override
  Map<String, dynamic> prepareFilterParams(
    Map<String, dynamic> selectedFilters,
  ) {
    final params = <String, dynamic>{};

    // Procesar filtro de ordenamiento
    final orderByValue = selectedFilters['orderBy'] as String?;
    
    if (orderByValue != null) {
      // Mapear los valores del filtro a los parámetros del repositorio
      switch (orderByValue) {
        case 'date_added':
          // Por defecto, no se necesitan parámetros adicionales
          break;
        case 'date_published':
          params['orderBy'] = 'date';
          params['orderByKey'] = 'published';
          break;
        case 'popular_today':
          params['orderBy'] = 'popular';
          params['orderByKey'] = 'today';
          break;
        case 'popular_week':
          params['orderBy'] = 'popular';
          params['orderByKey'] = 'week';
          break;
        case 'popular_month':
          params['orderBy'] = 'popular';
          params['orderByKey'] = 'month';
          break;
        case 'popular_year':
          params['orderBy'] = 'popular';
          params['orderByKey'] = 'year';
          break;
      }
    }

    return params;
  }
}
