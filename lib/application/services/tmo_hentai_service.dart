import 'package:html/parser.dart' as html_parser;
import '../../domain/entities/manga_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/editorial_entity.dart';
import '../../domain/entities/filter_entity.dart';
import '../interfaces/i_manga_service.dart';
import '../../domain/interfaces/i_tmo_hentai_repository.dart';
import '../../infrastructure/data/tmo_hentai_tags.dart';

/// Servicio TMO Hentai que implementa IMangaService
/// Maneja las peticiones específicas a tmohentai.com
class TmoHentaiService implements IMangaService {
  final ITmoHentaiRepository _tmoHentaiRepository;

  TmoHentaiService({required ITmoHentaiRepository tmoHentaiRepository})
    : _tmoHentaiRepository = tmoHentaiRepository;

  @override
  String get serverName => 'tmo_hentai';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final htmlContent = await _tmoHentaiRepository.getMangas(page);
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TmoHentaiService getAllMangas: $error');
    }
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      // Elimina los espacios en blanco al inicio y final de mangaId
      mangaId = mangaId.trim();
      // Para TMO Hentai, el mangaId es la URL completa del manga
      final htmlContent = await _tmoHentaiRepository.getMangaDetail(mangaId);
      final mangaDetail = _formatMangaDetail(htmlContent, mangaId);
      return mangaDetail;
    } catch (error) {
      throw Exception('Error en TmoHentaiService getMangaDetail: $error');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      // Para TMO Hentai, el chapterId es la URL completa del capítulo
      final htmlContent = await _tmoHentaiRepository.getChapterImages(
        chapterId,
      );
      final images = _extractImagesFromHtml(htmlContent);
      return images;
    } catch (error) {
      throw Exception('Error en TmoHentaiService getChapterImages: $error');
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      final htmlContent = await _tmoHentaiRepository.searchMangasByTitle(
        query,
        page,
      );
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TmoHentaiService searchManga: $error');
    }
  }

  @override
  Future<List<FilterGroupEntity>> getFilters() async {
    try {
      // Convertir tmo_hentai_tags en grupos de filtros
      final generoTags =
          tmoHentaiTags
              .where((item) => item['type'] == 'genero')
              .map(
                (item) => TagEntity(
                  name: item['name']!,
                  value: item['value']!,
                  type: TypeTagEntity.genero,
                ),
              )
              .toList();

      final orderByTags =
          tmoHentaiTags
              .where((item) => item['type'] == 'orderBy')
              .map(
                (item) => TagEntity(
                  name: item['name']!,
                  value: item['value']!,
                  type: TypeTagEntity.orderBy,
                ),
              )
              .toList();

      final orderDirTags =
          tmoHentaiTags
              .where((item) => item['type'] == 'orderDir')
              .map(
                (item) => TagEntity(
                  name: item['name']!,
                  value: item['value']!,
                  type: TypeTagEntity.orderDir,
                ),
              )
              .toList();

      return [
        FilterGroupEntity(
          key: 'hentai_generos',
          title: 'Géneros',
          filterType: FilterTypeEntity.checkbox,
          options: generoTags,
        ),
        FilterGroupEntity(
          key: 'hentai_order_by',
          title: 'Ordenar por',
          filterType: FilterTypeEntity.radio,
          options: orderByTags,
        ),
        FilterGroupEntity(
          key: 'hentai_order_dir',
          title: 'Dirección',
          filterType: FilterTypeEntity.radio,
          options: orderDirTags,
        ),
      ];
    } catch (error) {
      throw Exception('Error en TmoHentaiService getFilters: $error');
    }
  }

  @override
  Future<List<MangaEntity>> applyFilter(
    int page,
    Map<String, dynamic> selectedFilters,
  ) async {
    try {
      // Preparar los parámetros usando el método helper
      final params = prepareFilterParams(selectedFilters);

      // Llamar al repositorio con los parámetros preparados
      final htmlContent = await _tmoHentaiRepository.applyFilter(
        page: page,
        selectedGenres: params['selectedGenres'] as List<int>,
        orderBy: params['orderBy'] as String?,
        orderDir: params['orderDir'] as String?,
        searchText: params['searchText'] as String?,
      );

      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TmoHentaiService applyFilter: $error');
    }
  }

  @override
  Map<String, dynamic> prepareFilterParams(
    Map<String, dynamic> selectedFilters,
  ) {
    // Extraer géneros
    List<int> selectedGenres = [];
    if (selectedFilters.containsKey('hentai_generos') &&
        selectedFilters['hentai_generos'] is List) {
      selectedGenres = List<int>.from(selectedFilters['hentai_generos']);
    }

    return {
      'selectedGenres': selectedGenres,
      'orderDir': selectedFilters['hentai_order_dir'],
      'orderBy': selectedFilters['hentai_order_by'],
      'searchText': selectedFilters['searchText'],
    };
  }

  /// Convierte el HTML de la lista de mangas en una lista de MangaEntity
  List<MangaEntity> _formatListManga(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      final elements = document.querySelectorAll('.work-thumbnail');

      return elements.map((element) {
        final titleElement = element.querySelector('.content-title');
        final title =
            titleElement != null
                ? titleElement.text.trim().replaceAll(RegExp(r'\s+'), ' ')
                : "Sin título";

        final linkImageElement = element.querySelector(
          '.content-thumbnail-cover',
        );
        final linkImage = linkImageElement?.attributes['src'] ?? '';

        final linkElement = element.querySelector('a');
        final link = linkElement?.attributes['href'] ?? '';

        final bookTypeElement = element.querySelector('div.type-info > span');
        final bookType = bookTypeElement?.attributes['title'] ?? 'Desconocido';

        const demography = "Hentai";

        // Para TMO Hentai, usamos el link completo como ID
        // Verificar si el link ya tiene el dominio completo
        String id;
        if (link.startsWith('http')) {
          id = link; // Ya tiene el dominio completo
        } else {
          id = 'https://tmohentai.com$link'; // Agregar dominio
        }

        return MangaEntity(
          id: id,
          title: title,
          coverImageUrl: linkImage,
          authors: [],
          genres: [demography, bookType],
          status: 'unknown',
          serverSource: serverName,
          referer: 'https://tmohentai.com',
        );
      }).toList();
    } catch (error) {
      throw Exception('Error formateando lista de manga: $error');
    }
  }

  /// Convierte el HTML de detalles del manga en un MangaEntity completo
  MangaEntity _formatMangaDetail(String htmlContent, String mangaUrl) {
    try {
      final document = html_parser.parse(htmlContent);

      // Extraer título
      final titleElement = document.querySelector('.panel-primary.panel-title');
      final title =
          titleElement?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ??
          'Sin título';

      // Extraer géneros, autor y editorial
      final contentProperties = document.querySelectorAll('.content-property');
      List<String> genres = [];
      String? autor;
      String? editorial;

      for (var property in contentProperties) {
        final headingElement = property.querySelector('li.heading label');
        if (headingElement == null) continue;

        // Extraer géneros
        if (headingElement.text.contains('Genders')) {
          final generoElements = property.querySelectorAll(
            'li:not(.heading) a',
          );
          genres =
              generoElements.map((element) => element.text.trim()).toList();
        }

        // Extraer autor (Artists)
        if (headingElement.text.contains('Artists')) {
          final artistElement = property.querySelector(
            'li:not(.heading) span.tag a',
          );
          if (artistElement != null) {
            autor = artistElement.text.trim();
          }
        }

        // Extraer editorial
        if (headingElement.text.contains('Uploaded By')) {
          final editorialElement = property.querySelector(
            'li:not(.heading) span.tag a',
          );
          if (editorialElement != null) {
            editorial = editorialElement.text.trim();
          }
        }
      }

      // Extraer capítulos
      final chapterElements = document.querySelectorAll(
        'div.panel-heading > div > a',
      );
      List<ChapterEntity> chapters = [];

      for (int i = 0; i < chapterElements.length; i++) {
        final item = chapterElements[i];
        var link = item.attributes['href'] ?? '';

        if (link.contains('paginated')) {
          // Reemplazar 'paginated/cualquier_número' por 'cascade?image-width=normal-width'
          link = link.replaceFirst(
            RegExp(r'paginated/\d+'),
            'cascade?image-width=normal-width',
          );
        }

        // Agregar número de capítulo al principio del título
        final chapterNumber = chapterElements.length - i;
        final numberedTitle = 'Capítulo $chapterNumber: $title';

        chapters.add(
          ChapterEntity(
            numAndTitleCap: numberedTitle,
            dateRelease: '', // No hay fecha disponible
            editorials: [
              EditorialEntity(
                editorialName: editorial ?? 'Desconocido',
                editorialLink: link,
              ),
            ],
          ),
        );
      }

      return MangaEntity(
        id: mangaUrl, // Usar la URL completa como ID
        title: title,
        coverImageUrl: '', // Se puede extraer si es necesario
        authors: autor != null ? [autor] : [],
        genres: genres,
        status: 'unknown',
        chapters: chapters,
        serverSource: serverName,
        referer: 'https://tmohentai.com',
      );
    } catch (error) {
      throw Exception('Error formateando detalles del manga: $error');
    }
  }

  /// Extrae las imágenes del HTML del capítulo
  List<String> _extractImagesFromHtml(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);

      // Seleccionar directamente todas las imágenes con clase 'content-image'
      final images = document.querySelectorAll('.content-image');

      // Extraer las URLs de las imágenes
      // Prioriza el atributo 'data-original' que contiene la imagen de alta calidad
      final imageLinks =
          images
              .map(
                (e) =>
                    e.attributes['data-original'] ?? e.attributes['src'] ?? '',
              )
              .where((url) => url.isNotEmpty)
              .toList();

      return imageLinks;
    } catch (error) {
      throw Exception('Error extrayendo imágenes: $error');
    }
  }
}
