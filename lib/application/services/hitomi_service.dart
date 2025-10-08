import 'package:mangari/application/interfaces/i_manga_service.dart';
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
      return _formatListManga(galleries);
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

  ChapterEntity _createSingleChapter(Map<String, dynamic> gallery, String mangaId) {
    // En Hitomi, cada galería es una obra completa
    final filesCount = gallery.containsKey('files') && gallery['files'] is List
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

      // Obtener datos de gg.js
      final ggData = await _hitomiRepository.getGGData();
      if (ggData == null) {
        print('Failed to get GG data');
        return [];
      }

      // Construir URLs de las imágenes
      final images = <String>[];
      final files = gallery['files'] as List;

      for (final file in files) {
        if (file is Map && file.containsKey('name') && file.containsKey('hash')) {
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

      final extension = hasAvif
          ? 'avif'
          : name.split('.').last.toLowerCase();

      // Usar la función s de ggData para obtener el subdirectorio
      final sFunction = ggData['s'] as String Function(String);
      final basePath = ggData['b'] as String;
      
      // Construir el path completo: basePath + subdirectory + hash
      // Ejemplo: 1759953601/ + 864/ + hash
      final fullPath = basePath + sFunction(hash) + hash;

      // Calcular subdominio usando la función real de Hitomi
      final subdomain = _getHitomiSubdomain(hash, hasAvif, ggData);

      // Construir URL final
      final imageUrl = 'https://$subdomain.gold-usergeneratedcontent.net/$fullPath.$extension';

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
      // Implementar la lógica de subdomain_from_url del common.js
      String retval = hasAvif ? 'a' : 'b';

      // Extraer los últimos 3 caracteres del hash como en el código original
      final match = RegExp(r'([0-9a-f]{2})([0-9a-f])$').firstMatch(hash);

      if (match == null) {
        return '${retval}1'; // Fallback
      }

      // Convertir de hexadecimal a decimal (base 16)
      // El formato es: último_char + penúltimos_2_chars
      final hexPart = match.group(2)! + match.group(1)!;
      final g = int.parse(hexPart, radix: 16);

      // La función m de gg.js devuelve 0 o 1
      final mFunction = ggData['m'] as int Function(int);
      final moduleResult = mFunction(g);
      
      // Debug: ver qué valor retorna m(g)
      print('Hash: $hash, Last3: $hexPart, g: $g, m(g): $moduleResult');
      
      // Según el código TS: return 1 + ggData.m(g)
      final subdomainNumber = 1 + moduleResult;
      retval = retval + subdomainNumber.toString();

      return retval;
    } catch (error) {
      print('Error calculating Hitomi subdomain: $error');
      return hasAvif ? 'a1' : 'b1'; // Fallback
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      // Hitomi no tiene búsqueda específica, retornamos la lista normal
      return await getAllMangas(page: page, limit: 20);
    } catch (error) {
      print('Error en HitomiService searchManga: $error');
      return [];
    }
  }
}
