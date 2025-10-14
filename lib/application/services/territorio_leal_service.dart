import 'package:html/parser.dart' as html_parser;
import '../../domain/entities/manga_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/editorial_entity.dart';
import '../../domain/entities/filter_entity.dart';
import '../interfaces/i_manga_service.dart';
import '../../domain/interfaces/i_territorio_leal_repository.dart';

/// Servicio Territorio Leal que implementa IMangaService
/// Maneja las peticiones específicas a territorioprotegido.xyz
class TerritorioLealService implements IMangaService {
  final ITerritorioLealRepository _territorioLealRepository;

  TerritorioLealService({
    required ITerritorioLealRepository territorioLealRepository,
  }) : _territorioLealRepository = territorioLealRepository;

  @override
  String get serverName => 'territorio_leal';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final htmlContent = await _territorioLealRepository.getMangas(page);
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TerritorioLealService getAllMangas: $error');
    }
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      // Para Territorio Leal, el mangaId es la URL completa del manga
      final htmlContent = await _territorioLealRepository.getMangaDetail(
        mangaId,
      );
      final mangaDetail = _formatMangaDetail(htmlContent, mangaId);
      return mangaDetail;
    } catch (error) {
      throw Exception('Error en TerritorioLealService getMangaDetail: $error');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      // Para Territorio Leal, el chapterId es la URL completa del capítulo
      final htmlContent = await _territorioLealRepository.getChapterImages(
        chapterId,
      );
      final images = _extractChapterImages(htmlContent);
      return images;
    } catch (error) {
      throw Exception(
        'Error en TerritorioLealService getChapterImages: $error',
      );
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      final htmlContent = await _territorioLealRepository.searchManga(
        query,
        page,
      );
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TerritorioLealService searchManga: $error');
    }
  }

  @override
  Future<List<FilterGroupEntity>> getFilters() async {
    try {
      // Por ahora retornamos una lista vacía hasta implementar filtros específicos
      return [];
    } catch (error) {
      throw Exception('Error en TerritorioLealService getFilters: $error');
    }
  }

  @override
  Future<List<MangaEntity>> applyFilter(
    int page,
    Map<String, dynamic> selectedFilters,
  ) async {
    try {
      final htmlContent = await _territorioLealRepository.applyFilters(
        selectedFilters,
        page,
      );
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TerritorioLealService applyFilter: $error');
    }
  }

  @override
  Map<String, dynamic> prepareFilterParams(
    Map<String, dynamic> selectedFilters,
  ) {
    // Por ahora retornamos los mismos filtros hasta implementar lógica específica
    return selectedFilters;
  }

  /// Formatea la lista de mangas desde el HTML recibido
  List<MangaEntity> _formatListManga(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      final List<MangaEntity> mangas = [];

      // Buscar elementos que contienen información de manga
      final elements = document.querySelectorAll('.col-12.col-md-4');

      for (var element in elements) {
        try {
          // Extraer ID del manga desde el elemento
          String id = element.id;
          String mangaId = id.isNotEmpty ? id.replaceAll('post-', '') : '0';

          // Extraer título
          final titleElement = element.querySelector('.heading > a');
          final title = titleElement?.text.trim() ?? 'Sin título';

          // Extraer URL del manga
          final link = titleElement?.attributes['href'] ?? '';

          // Extraer URL de la imagen
          final imgElement = element.querySelector('.c-blog__thumbnail img');
          String linkImage =
              imgElement?.attributes['data-src'] ??
              imgElement?.attributes['src'] ??
              '';

          // Optimizar la imagen a un tamaño específico
          if (linkImage.isNotEmpty) {
            linkImage = linkImage.replaceAllMapped(
              RegExp(r'-\d+x\d+\.(jpg|jpeg|png|webp|gif|bmp)'),
              (match) => '-193x278.${match.group(1)}',
            );
          }

          // Crear el objeto MangaEntity si tenemos información válida
          if (title.isNotEmpty && link.isNotEmpty) {
            final manga = MangaEntity(
              id: link,
              title: title,
              coverImageUrl: linkImage,
              status: 'Desconocido',
              serverSource: 'territorio_leal',
              referer: 'https://territorioprotegido.xyz/',
              authors: ['Autor desconocido'],
              genres: ['Ecchi'], // Género por defecto
            );

            mangas.add(manga);
          }
        } catch (e) {
          print(
            'Error procesando elemento individual en TerritorioLealService: $e',
          );
          continue;
        }
      }

      return mangas;
    } catch (e) {
      print('Error en _formatListManga de TerritorioLealService: $e');
      return [];
    }
  }

  /// Formatea los detalles del manga desde el HTML recibido
  MangaEntity _formatMangaDetail(String htmlContent, String mangaId) {
    try {
      final document = html_parser.parse(htmlContent);
      final List<ChapterEntity> chapters = [];

      // Extraer información de los capítulos
      final chapterElements = document.querySelectorAll('.wp-manga-chapter');

      for (var chapterElement in chapterElements) {
        try {
          // Extraer el título del capítulo
          final chapterTitle =
              chapterElement.querySelector('a')?.text.trim() ?? '';

          // Extraer el enlace del capítulo
          final chapterLink =
              chapterElement.querySelector('a')?.attributes['href'] ?? '';

          // Extraer la fecha de publicación
          final dateRelease =
              chapterElement
                  .querySelector('.chapter-release-date i')
                  ?.text
                  .trim() ??
              '';

          // Crear el objeto ChapterEntity si tenemos información válida
          if (chapterTitle.isNotEmpty && chapterLink.isNotEmpty) {
            final editorials = [
              EditorialEntity(
                editorialName: 'Territorio Leal',
                editorialLink: chapterLink,
              ),
            ];

            final chapter = ChapterEntity(
              numAndTitleCap: chapterTitle,
              dateRelease:
                  dateRelease.isNotEmpty ? dateRelease : 'Fecha desconocida',
              editorials: editorials,
            );

            chapters.add(chapter);
          }
        } catch (e) {
          print('Error procesando capítulo en TerritorioLealService: $e');
          continue;
        }
      }

      // Crear el objeto MangaEntity con los detalles
      return MangaEntity(
        id: mangaId,
        title: '', // Se puede extraer del HTML si es necesario
        description: 'Descripción no disponible',
        coverImageUrl: null,
        authors: ['Autor desconocido'],
        genres: ['Género desconocido'],
        status: 'Desconocido',
        serverSource: 'territorio_leal',
        referer: 'https://territorioprotegido.xyz/',
        chapters: chapters,
      );
    } catch (e) {
      print('Error en _formatMangaDetail de TerritorioLealService: $e');
      // Retornar un manga básico en caso de error
      return MangaEntity(
        id: mangaId,
        title: 'Error al cargar',
        status: 'Error',
        serverSource: 'territorio_leal',
        referer: 'https://territorioprotegido.xyz/',
      );
    }
  }

  /// Extrae las imágenes del capítulo desde el HTML
  List<String> _extractChapterImages(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      final List<String> imageUrls = [];

      // Buscar los contenedores de imágenes
      final imageContainers = document.querySelectorAll(
        '.reading-content .page-break',
      );

      for (var container in imageContainers) {
        final imgElement = container.querySelector('img.wp-manga-chapter-img');

        // Intentar obtener la URL desde el atributo src primero
        String? imgUrl = imgElement?.attributes['src'];

        // Si no está en src, intentar con data-src
        if (imgUrl == null || imgUrl.isEmpty) {
          imgUrl = imgElement?.attributes['data-src'];
        }

        // Limpiar la URL y añadirla a la lista
        if (imgUrl != null && imgUrl.isNotEmpty) {
          imgUrl = imgUrl.trim();
          if (imgUrl.isNotEmpty) {
            imageUrls.add(imgUrl);
          }
        }
      }

      return imageUrls;
    } catch (e) {
      print('Error en _extractChapterImages de TerritorioLealService: $e');
      return [];
    }
  }
}
