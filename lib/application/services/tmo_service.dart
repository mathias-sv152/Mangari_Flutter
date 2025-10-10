import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../domain/entities/manga_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/editorial_entity.dart';
import '../interfaces/i_manga_service.dart';
import '../../domain/interfaces/i_tmo_repository.dart';
import '../../infrastructure/utils/html_utils.dart';

/// Servicio TMO que implementa IMangaService
/// Maneja las peticiones específicas a zonatmo.com
class TmoService implements IMangaService {
  final ITmoRepository _tmoRepository;

  TmoService({required ITmoRepository tmoRepository}) 
      : _tmoRepository = tmoRepository;

  @override
  String get serverName => 'TMO';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final htmlContent = await _tmoRepository.getManga(page);
      final mangaList = _formatListManga(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error en TmoService getAllMangas: $error');
    }
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      //elimina los espacios en blanco al inicio y final de mangaid
      mangaId = mangaId.trim();
      // Para TMO, el mangaId es la URL completa del manga
      final htmlContent = await _tmoRepository.getMangaDetail(mangaId);
      final mangaDetail = _formatMangaDetail(htmlContent, mangaId);
      return mangaDetail;
    } catch (error) {
      throw Exception('Error en TmoService getMangaDetail: $error');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      // Para TMO, el chapterId es la URL completa del capítulo
      final htmlContent = await _tmoRepository.getChapterDetail(chapterId);
      
      final document = html_parser.parse(htmlContent);
      
      // 1. Buscamos el uniqid en los scripts
      String? uniqid = _extractUniqidFromScripts(document);

      // 2. Si no lo encontramos, intentamos extraerlo de la meta tag og:url
      if (uniqid == null) {
        uniqid = _extractUniqidFromMetaTags(document);
      }

      // Si encontramos el uniqid, procedemos a obtener las imágenes
      if (uniqid != null) {
        // Construimos la URL para obtener las imágenes
        final imagesUrl = 'https://zonatmo.com/viewer/$uniqid/cascade';

        // Obtenemos el HTML de la página con las imágenes
        final imagesResponse = await _tmoRepository.getChapterDetail(imagesUrl);
        final imagesDocument = html_parser.parse(imagesResponse);

        // Extraemos las imágenes del contenedor principal
        return _extractImagesFromDocument(imagesDocument);
      }

      throw Exception('No se pudo encontrar el uniqid para cargar las imágenes');
    } catch (error) {
      throw Exception('Error en TmoService getChapterImages: $error');
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      // TMO no tiene búsqueda específica en el TS original, 
      // por ahora retornamos la lista normal
      return await getAllMangas(page: page, limit: 20);
    } catch (error) {
      throw Exception('Error en TmoService searchManga: $error');
    }
  }

  /// Formatea la lista de manga desde HTML
  List<MangaEntity> _formatListManga(String html) {
    try {
      final document = html_parser.parse(html);

      // Encontrar todos los elementos con la clase "element"
      final elements = HtmlUtils.findElementsByClass(document, 'element');

      final mangas = <MangaEntity>[];

      for (int i = 0; i < elements.length; i++) {
        final element = elements[i];

        // Obtener el enlace del manga
        final linkElement = HtmlUtils.findElement(element, 'a');
        final link = HtmlUtils.getAttribute(linkElement, 'href');

        // Obtener la URL de la imagen
        String imageUrl = '';
        if (linkElement != null) {
          final linkDiv = HtmlUtils.findElement(linkElement, 'div');
          if (linkDiv != null) {
            final styleElement = HtmlUtils.findElement(linkDiv, 'style');
            if (styleElement != null) {
              final styleText = HtmlUtils.getTextContent(styleElement);
              final match = RegExp(r'url\((.*?)\)').firstMatch(styleText);
              if (match != null && match.group(1) != null) {
                imageUrl = match.group(1)!.replaceAll("'", "").replaceAll('"', "");
              }
            }
          }
        }

        // Obtener el título
        final titleElement = HtmlUtils.findElement(element, 'h4.text-truncate');
        final title = HtmlUtils.getAttribute(titleElement, 'title');

        // Obtener el tipo de libro (manga/manhwa/etc)
        final bookTypeElement = HtmlUtils.findElement(element, '.book-type');
        final bookType = HtmlUtils.getTextContent(bookTypeElement);

        // Obtener la demografía
        final demographyElement = HtmlUtils.findElement(element, '.demography');
        final demography = HtmlUtils.getTextContent(demographyElement);

        // Crear objeto manga y añadirlo al array
        if (title.isNotEmpty && link.isNotEmpty) {
          mangas.add(
            MangaEntity(
              id: link, // Usamos el link como ID único para TMO
              title: title,
              coverImageUrl: imageUrl.isNotEmpty ? imageUrl : null,
              status: demography.isNotEmpty ? demography : 'unknown',
              serverSource: 'tmo',
              genres: bookType.isNotEmpty ? [bookType] : [],
              referer: 'https://zonatmo.com',
            ),
          );
        }
      }

      return mangas;
    } catch (e) {
      throw Exception('Error procesando HTML: $e');
    }
  }

  /// Formatea los detalles de un manga desde HTML
  MangaEntity _formatMangaDetail(String html, String mangaLink) {
    try {
      final document = html_parser.parse(html);
      
      // Comenzar con los datos básicos que tenemos del link
      final titleElement = HtmlUtils.findElement(document, 'section.element-header-content > div.container.h-100 > div > div.col-12.col-md-9.element-header-content-text > h1');
      final title = HtmlUtils.getTextContent(titleElement).replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Extraer descripción
      String? description;
      final descriptionElement = HtmlUtils.findElement(document, 'p.element-description, .description, .summary');
      if (descriptionElement != null) {
        description = HtmlUtils.getTextContent(descriptionElement);
      }

      // Extraer géneros
      final genreElements = HtmlUtils.findElements(document, 'div.col-12.col-md-9.element-header-content-text > h6 > a, .genres a, .tags a');
      final genres = genreElements.map((element) => HtmlUtils.getTextContent(element)).where((text) => text.isNotEmpty).toList();

      // Extraer autor
      String? author;
      final autorContainer = HtmlUtils.findElement(document, '.card-body.p-2 a, .author');
      if (autorContainer != null) {
        final autorElement = HtmlUtils.findElement(autorContainer, 'h5') ?? autorContainer;
        author = HtmlUtils.getTextContent(autorElement);
      }

      // Extraer estado
      final statusElement = HtmlUtils.findElement(document, 'span.book-status, .status');
      final status = HtmlUtils.getTextContent(statusElement);

      // Extraer capítulos
      final chapters = _extractChapters(document);
      
      // Extraer imagen de portada
      String? coverImageUrl;
      final imageElement = HtmlUtils.findElement(document, '.cover img, .thumbnail img, img[src*="cover"]');
      if (imageElement != null) {
        coverImageUrl = HtmlUtils.getAttribute(imageElement, 'src');
        if (coverImageUrl.isEmpty) {
          coverImageUrl = HtmlUtils.getAttribute(imageElement, 'data-src');
        }
      }

      return MangaEntity(
        id: mangaLink,
        title: title.isNotEmpty ? title : 'Título desconocido',
        description: description,
        coverImageUrl: coverImageUrl,
        authors: author != null ? [author] : [],
        genres: genres,
        status: status.isNotEmpty ? status : 'unknown',
        chapters: chapters,
        serverSource: 'tmo',
        referer: 'https://zonatmo.com',
      );
    } catch (e) {
      throw Exception('Error procesando HTML de detalles: $e');
    }
  }

  /// Extrae los capítulos del documento HTML
  List<ChapterEntity> _extractChapters(dom.Document document) {
    final allChapters = <ChapterEntity>[];

    // Extraer capítulos (primer selector: #chapters > ul > li)
    final chapterElements1 = HtmlUtils.findElements(document, '#chapters > ul > li');
    allChapters.addAll(_parseChapterElements(chapterElements1));

    // Extraer capítulos (segundo selector: #chapters > ul > div > li)
    final chapterElements2 = HtmlUtils.findElements(document, '#chapters > ul > div > li');
    allChapters.addAll(_parseChapterElements(chapterElements2));

    // Si no hay capítulos, intentar con oneshot
    if (allChapters.isEmpty) {
      final oneshotChapter = _extractOneshotChapter(document);
      if (oneshotChapter != null) {
        allChapters.add(oneshotChapter);
      }
    }

    return allChapters;
  }

  /// Parsea una lista de elementos de capítulos
  List<ChapterEntity> _parseChapterElements(List<dom.Element> chapterElements) {
    final chapters = <ChapterEntity>[];

    for (final chapterElement in chapterElements) {
      // Obtener número y título del capítulo
      final numCapElement = HtmlUtils.findElement(
        chapterElement,
        'h4 > div > div.col-10.text-truncate > a',
      );
      final numAndTitleCap = numCapElement != null
          ? HtmlUtils.getTextContent(numCapElement).trim()
          : '';

      // Si no hay título de capítulo, saltamos este elemento
      if (numAndTitleCap.isEmpty) continue;

      // Obtener elementos de editorial
      final editorialElements = HtmlUtils.findElements(
        chapterElement,
        'div > div > ul > li',
      );
      final editorials = <EditorialEntity>[];

      for (final editorialElement in editorialElements) {
        // Nombre de la editorial
        final nameElement = HtmlUtils.findElement(
          editorialElement,
          'div > div.col-4.col-md-6.text-truncate > span',
        );
        final editorialName = nameElement != null
            ? HtmlUtils.getTextContent(nameElement).replaceAll(RegExp(r'\s+'), ' ').trim()
            : 'N/A';

        // Link de la editorial
        final linkElement = HtmlUtils.findElement(
          editorialElement,
          'div > div.col-2.col-sm-1.text-right > a',
        );
        var editorialLink = linkElement != null
            ? HtmlUtils.getAttribute(linkElement, 'href')
            : '';

        // Reemplazar dominio si es necesario
        if (editorialLink.isNotEmpty && editorialLink.contains('visortmo.com')) {
          editorialLink = editorialLink.replaceAll(
            'https://visortmo.com',
            'https://lectortmo.com',
          );
        }

        // Fecha de publicación
        final dateElement = HtmlUtils.findElement(
          editorialElement,
          'div > div.col-4.col-md-2.text-center > span',
        );
        final dateRelease = dateElement != null
            ? HtmlUtils.getTextContent(dateElement).trim()
            : '';

        editorials.add(
          EditorialEntity(
            editorialName: editorialName,
            editorialLink: editorialLink,
            dateRelease: dateRelease,
          ),
        );
      }

      // Solo agregamos el capítulo si tiene editoriales
      if (editorials.isNotEmpty) {
        // Fecha de lanzamiento del capítulo
        final dateElement = HtmlUtils.findElement(
          chapterElement,
          'div > div > ul > li > div > div.col-4.col-md-2.text-center > span',
        );
        final dateRelease = dateElement != null
            ? HtmlUtils.getTextContent(dateElement).trim()
            : '';

        chapters.add(
          ChapterEntity(
            numAndTitleCap: numAndTitleCap,
            dateRelease: dateRelease,
            editorials: editorials,
          ),
        );
      }
    }

    return chapters;
  }

  /// Extrae capítulo oneshot (cuando no hay capítulos regulares)
  ChapterEntity? _extractOneshotChapter(dom.Document document) {
    final oneshotElements = HtmlUtils.findElements(
      document,
      '.chapter-list-element .list-group-item',
    );
    final oneshotEditorials = <EditorialEntity>[];

    for (final element in oneshotElements) {
      // Nombre de la editorial
      final nameElement = HtmlUtils.findElement(
        element,
        '.col-4.col-md-6.text-truncate > span',
      );
      final editorialName = nameElement != null
          ? HtmlUtils.getTextContent(nameElement).trim()
          : '';

      // Fecha de publicación
      final dateElement = HtmlUtils.findElement(
        element,
        '.col-4.col-md-2.text-center > span',
      );
      final dateRelease = dateElement != null
          ? HtmlUtils.getTextContent(dateElement).trim()
          : '';

      // Link de la editorial
      final linkElement = HtmlUtils.findElement(
        element,
        '.col-2.text-right > a',
      );
      final editorialLink = linkElement != null
          ? HtmlUtils.getAttribute(linkElement, 'href')
          : '';

      oneshotEditorials.add(
        EditorialEntity(
          editorialName: editorialName,
          editorialLink: editorialLink,
          dateRelease: dateRelease,
        ),
      );
    }

    if (oneshotEditorials.isNotEmpty) {
      return ChapterEntity(
        numAndTitleCap: '',
        dateRelease: '',
        editorials: oneshotEditorials,
      );
    }

    return null;
  }  /// Extrae el uniqid de los scripts de la página
  String? _extractUniqidFromScripts(dom.Document document) {
    try {
      final scriptElements = HtmlUtils.getElementsByTagName(document, 'script');

      for (final script in scriptElements) {
        // Verificar que el script no tenga atributo src
        if (!script.attributes.containsKey('src')) {
          final scriptContent = HtmlUtils.getTextContent(script);
          // Buscar el patrón uniqid: 'valor' o uniqid: "valor"
          if (scriptContent.contains('uniqid:')) {
            final parts = scriptContent.split('uniqid:');
            if (parts.length > 1) {
              final afterUniqid = parts[1].trim();
              // Buscar comillas simples primero
              int quoteStart = afterUniqid.indexOf("'");
              String quote = "'";
              if (quoteStart < 0) {
                // Si no hay comillas simples, buscar comillas dobles
                quoteStart = afterUniqid.indexOf('"');
                quote = '"';
              }
              if (quoteStart >= 0) {
                final valueStart = quoteStart + 1;
                final valueEnd = afterUniqid.indexOf(quote, valueStart);
                if (valueEnd > valueStart) {
                  return afterUniqid.substring(valueStart, valueEnd);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error extrayendo uniqid de scripts: $e');
    }
    return null;
  }

  /// Extrae el uniqid de las meta tags
  String? _extractUniqidFromMetaTags(dom.Document document) {
    try {
      final metaTags = HtmlUtils.getElementsByTagName(document, 'meta');

      for (final meta in metaTags) {
        if (HtmlUtils.getAttribute(meta, 'property') == 'og:url') {
          final content = HtmlUtils.getAttribute(meta, 'content');
          // Extraer el uniqid del formato viewer/uniqid/(cascade|paginate)
          final match = RegExp(r'viewer/([^/]+)/(cascade|paginate)').firstMatch(content);
          if (match != null && match.group(1) != null) {
            return match.group(1);
          }
        }
      }
    } catch (e) {
      print('Error extrayendo uniqid de meta tags: $e');
    }
    return null;
  }

  /// Extrae las URLs de las imágenes del documento de imágenes
  List<String> _extractImagesFromDocument(dom.Document document) {
    try {
      final images = <String>[];

      // Buscar todos los divs dentro del contenedor principal
      final divContainers = HtmlUtils.findElements(document, '#main-container > div');

      for (final container in divContainers) {
        final imgElement = HtmlUtils.findElement(container, 'img');

        if (imgElement != null) {
          // Obtener la URL de la imagen del atributo data-src
          final imgSrc = HtmlUtils.getAttribute(imgElement, 'data-src');
          if (imgSrc.isNotEmpty) {
            images.add(imgSrc);
          }
        }
      }
      
      return images;
    } catch (e) {
      throw Exception('Error extrayendo imágenes: $e');
    }
  }
}