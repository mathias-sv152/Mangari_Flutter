import 'package:flutter/material.dart';
import 'package:mangari/application/interfaces/i_manga_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mangari/domain/entities/chapter_entity.dart';
import 'package:mangari/domain/entities/editorial_entity.dart';
import 'package:mangari/domain/entities/filter_entity.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_uchuujin_repository.dart';
import 'package:mangari/infrastructure/utils/html_utils.dart';

class UchuujinService implements IMangaService {
  final IUchuujinRepository _uchuujinRepository;

  UchuujinService({required IUchuujinRepository repository})
    : _uchuujinRepository = repository;

  @override
  String get serverName => "uchuujin";

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> applyFilter(
    int page,
    Map<String, dynamic> selectedFilters,
  ) {
    // TODO: implement applyFilter
    throw UnimplementedError();
  }

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final htmlContent = await _uchuujinRepository.getMangas(page);
      final mangaList = _parseMangaList(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error in UchuujinService getAllMangas: $error');
    }
  }

  List<MangaEntity> _parseMangaList(String htmlContent) {
    try {
      // Aquí iría la lógica para parsear el HTML y extraer la lista de mangas
      final document = html_parser.parse(htmlContent);
      final elements = document.querySelectorAll('div.listupd .bs');

      final mangas = <MangaEntity>[];

      for (var element in elements) {
        final titleElement = element.querySelector('div.bigor > div.tt');
        final title = titleElement?.text.trim() ?? 'No Title';
        final linkElement = element.querySelector('div > a');
        final link = linkElement?.attributes['href'] ?? '';
        final finalCapUpdate =
            element.querySelector('div.adds > div.epxs')?.text.trim() ?? '';
        final coverImageUrl =
            element.querySelector('div.limit > img')?.attributes['src'] ?? '';

        final manga = MangaEntity(
          id: link, // Usar el link como ID temporalmente
          title: title,
          coverImageUrl: coverImageUrl,
          serverSource: 'uchuujin',
          status: finalCapUpdate,
          referer: 'https://uchuujinmangas.com',
        );

        mangas.add(manga);
      }

      return mangas;
    } catch (e) {
      throw Exception('Error procesando HTML: $e');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      final htmlContent = await _uchuujinRepository.getChapterImages(chapterId);
      return _parseChapterImagesNoscriptOnly(htmlContent);
    } catch (error) {
      throw Exception('Error in UchuujinService getChapterImages: $error');
    }
  }

  List<String> _parseChapterImagesNoscriptOnly(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);

      // Accede al innerHtml de <noscript> dentro de #readerarea
      final noscriptHtml =
          document.querySelector('#readerarea > noscript')?.innerHtml ?? '';

      // Parsea el HTML de noscript para obtener los <img>
      final noscriptDocument = html_parser.parse(noscriptHtml);
      final noscriptImages = noscriptDocument.querySelectorAll('img');

      // Extrae los src de cada imagen
      final imageUrls = <String>[];
      for (var imgElement in noscriptImages) {
        final imgUrl = imgElement.attributes['src'];
        if (imgUrl != null && imgUrl.isNotEmpty) {
          imageUrls.add(imgUrl);
        }
      }

      return imageUrls;
    } catch (e) {
      throw Exception('Error parsing noscript chapter images: $e');
    }
  }

  @override
  Future<List<FilterGroupEntity>> getFilters() {
    // TODO: implement getFilters
    throw UnimplementedError();
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      mangaId = mangaId.trim();
      final htmlContent = await _uchuujinRepository.getMangaDetail(mangaId);
      return _formatMangaDetail(htmlContent, mangaId);
    } catch (error) {
      throw Exception('Error in UchuujinService getMangaDetail: $error');
    }
  }

  MangaEntity _formatMangaDetail(String html, String mangaLink) {
    try {
      final document = html_parser.parse(html);

      // Título principal
      final title =
          document.querySelector('#titlemove > h1.entry-title')?.text.trim();

      // Título alternativo
      // final alternativeTitle = document.querySelector('#titlemove > span.alternative')?.text.trim();

      // Descripción (sinopsis)
      final description =
          document
              .querySelector('div.entry-content.entry-content-single')
              ?.text
              .trim();

      // Imagen de portada
      final coverImageUrl =
          document.querySelector('div.thumb > img')?.attributes['src'];

      // Autor
      final author =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(4) > i')
              ?.text
              .trim();

      // Artista
      final artist =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(5) > i')
              ?.text
              .trim();

      // Estado (Ongoing/Completed)
      final status =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(1) > i')
              ?.text
              .trim() ??
          'Unknown';

      // Tipo (Manga/Manhwa/Manhua)
      final type =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(2) > a')
              ?.text
              .trim();

      // Año de lanzamiento
      final yearText =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(3) > i')
              ?.text
              .trim();
      final year = yearText != null ? int.tryParse(yearText) : null;

      // Rating
      final ratingText =
          document.querySelector('div.rating-prc > div.num')?.text.trim();
      final rating = ratingText != null ? double.tryParse(ratingText) : null;

      // Géneros
      final genres = <String>[];
      final genreElements = document.querySelectorAll(
        'div.wd-full span.mgen > a',
      );
      for (var genreElement in genreElements) {
        final genre = genreElement.text.trim();
        if (genre.isNotEmpty) {
          genres.add(genre);
        }
      }

      // Capítulos
      final chapters = <ChapterEntity>[];
      final chapterElements = document.querySelectorAll(
        'div.eplister ul.clstyle > li',
      );

      for (var chapterElement in chapterElements) {
        final chapterLink =
            chapterElement.querySelector('div.eph-num > a')?.attributes['href'];
        final chapterNumElement = chapterElement.querySelector(
          'span.chapternum',
        );

        if (chapterNumElement != null && chapterLink != null) {
          // Extraer número y título del capítulo
          final chapterText = chapterNumElement.text.trim();
          final chapterSubtitle =
              chapterNumElement.querySelector('i')?.text.trim() ?? '';

          // Construir el texto completo del capítulo
          String fullChapterText = chapterText;
          if (chapterSubtitle.isNotEmpty) {
            fullChapterText =
                chapterText.replaceAll(chapterSubtitle, '').trim() +
                chapterSubtitle;
          }

          // Fecha de lanzamiento
          final dateRelease =
              chapterElement.querySelector('span.chapterdate')?.text.trim() ??
              '';

          // Crear editorial con el link del capítulo
          final editorial = EditorialEntity(
            editorialName: 'uchuujin',
            editorialLink: chapterLink,
            dateRelease: dateRelease,
          );

          chapters.add(
            ChapterEntity(
              numAndTitleCap: fullChapterText,
              dateRelease: dateRelease,
              editorials: [editorial],
            ),
          );
        }
      }

      // Fecha de última actualización
      final lastUpdatedText =
          document
              .querySelector('div.tsinfo.bixbox > div:nth-child(9) > i > time')
              ?.attributes['datetime'];
      DateTime? lastUpdated;
      if (lastUpdatedText != null) {
        lastUpdated = DateTime.tryParse(lastUpdatedText);
      }

      return MangaEntity(
        id: mangaLink,
        title: title ?? 'No Title',
        description: description,
        coverImageUrl: coverImageUrl,
        authors: [
          if (author != null) author,
          if (artist != null && artist != author) artist,
        ],
        genres: genres,
        status: status,
        year: year,
        rating: rating,
        chapterCount: chapters.length,
        chapters: chapters,
        lastUpdated: lastUpdated,
        serverSource: 'uchuujin',
        referer: 'https://uchuujinmangas.com',
        originalLanguage: 'es', // Spanish
        availableLanguages: ['es'],
      );
    } catch (error) {
      throw Exception('Error formatting manga detail: $error');
    }
  }

  @override
  Map<String, dynamic> prepareFilterParams(
    Map<String, dynamic> selectedFilters,
  ) {
    // TODO: implement prepareFilterParams
    throw UnimplementedError();
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      final htmlContent = await _uchuujinRepository.searchMangasByTitle(
        query,
        page,
      );
      final mangaList = _parseMangaList(htmlContent);
      return mangaList;
    } catch (error) {
      throw Exception('Error in UchuujinService searchManga: $error');
    }
  }
}
