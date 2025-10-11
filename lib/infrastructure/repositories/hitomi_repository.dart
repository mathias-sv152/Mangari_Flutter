import 'dart:convert';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:mangari/domain/interfaces/i_hitomi_repository.dart';
import 'package:mangari/infrastructure/utils/html_utils.dart';

class HitomiRepository implements IHitomiRepository {
  final String _baseUrl = "https://hitomi.la";
  final http.Client _httpClient;
  
  // Fallback en caso de error de red - Solo para emergencias, no para caché normal
  Map<String, dynamic>? _cachedGGData;

  HitomiRepository(this._httpClient);

  @override
  Future<List<Map<String, dynamic>>> getManga(int page) async {
    try {
      // Usar el método nozomi para obtener las galerías
      return await _getMangaNozomi(page);
    } catch (error) {
      print('Error in HitomiRepository getManga: $error');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchManga(String genre, int page) async {
    try {
      // Actualmente no implementado - usar el método nozomi como fallback
      return await _getMangaNozomi(page);
    } catch (error) {
      print('Error in HitomiRepository getMangaByGenre: $error');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchMangaWithFilters(String query, int page, {String? orderBy, String? orderByKey}) {
    // Actualmente no implementado - usar el método nozomi como fallback
    return _getMangaNozomi(page);
  }

  Future<List<Map<String, dynamic>>> _getMangaNozomi(int page) async {
    try {
      // Hitomi usa un sistema de nozomi para las listas con paginación por bytes
      final nozomiUrl = 'https://ltn.gold-usergeneratedcontent.net/popular/year-spanish.nozomi';

      // Calcular el rango de bytes para la página
      const galleriesPerPage = 25;
      const bytesPerGallery = 4; // Cada ID de galería son 4 bytes
      final startByte = (page - 1) * galleriesPerPage * bytesPerGallery;
      final endByte = startByte + galleriesPerPage * bytesPerGallery - 1;

      // Headers necesarios según el curl
      final headers = {
        'Accept': '*/*',
        'Accept-Language': 'es-MX,es-419;q=0.9,es;q=0.8,en;q=0.7',
        'Origin': 'https://hitomi.la',
        'Priority': 'u=1, i',
        'Range': 'bytes=$startByte-$endByte',
        'Referer': 'https://hitomi.la/index-spanish.html?page=$page',
        'Sec-CH-UA': '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
        'Sec-CH-UA-Mobile': '?0',
        'Sec-CH-UA-Platform': '"Windows"',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
      };

      final response = await _httpClient.get(
        Uri.parse(nozomiUrl),
        headers: headers,
      );

      if (response.statusCode != 206 && response.statusCode != 200) {
        throw Exception('Failed to load nozomi file: ${response.statusCode}');
      }

      // Los archivos .nozomi contienen IDs de galerías en formato binario
      final galleryIds = _parseNozomiFile(response.bodyBytes);

      if (galleryIds.isEmpty) {
        print('No gallery IDs found in nozomi file');
        return [];
      }

      // Obtener información de las galerías usando los IDs
      final galleries = await _fetchGalleriesInfo(galleryIds);

      if (galleries.isEmpty) {
        print('No galleries info retrieved');
        return [];
      }

      return galleries;
    } catch (error) {
      print('Error in _getMangaNozomi: $error');
      throw error;
    }
  }

  List<int> _parseNozomiFile(Uint8List buffer) {
    try {
      final ids = <int>[];
      final byteData = ByteData.sublistView(buffer);

      // Cada ID es un entero de 4 bytes (big-endian)
      for (int i = 0; i < byteData.lengthInBytes; i += 4) {
        if (i + 4 <= byteData.lengthInBytes) {
          final id = byteData.getUint32(i, Endian.big);
          ids.add(id);
        }
      }

      return ids;
    } catch (error) {
      print('Error parsing nozomi file: $error');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGalleriesInfo(List<int> galleryIds) async {
    final galleries = <Map<String, dynamic>>[];
    const maxConcurrent = 3; // Reducir concurrencia para evitar saturar el servidor

    for (int i = 0; i < galleryIds.length; i += maxConcurrent) {
      final batch = galleryIds.skip(i).take(maxConcurrent).toList();
      final futures = batch.map((id) => _fetchGalleryInfo(id));

      try {
        final results = await Future.wait(futures);
        for (final gallery in results) {
          if (gallery != null) {
            galleries.add(gallery);
          }
        }
      } catch (error) {
        print('Error fetching batch: $error');
      }
    }

    return galleries;
  }

  Future<Map<String, dynamic>?> _fetchGalleryInfo(int galleryId) async {
    try {
      // URL corregida para obtener el HTML de la galería
      final galleryUrl = 'https://ltn.gold-usergeneratedcontent.net/galleryblock/$galleryId.html';

      final headers = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'es-MX,es-419;q=0.9,es;q=0.8,en;q=0.7',
        'Origin': 'https://hitomi.la',
        'Referer': 'https://hitomi.la/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
      };

      final response = await _httpClient.get(
        Uri.parse(galleryUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        print('Failed to fetch gallery $galleryId: ${response.statusCode}');
        return null;
      }

      final htmlContent = response.body;

      // Parsear HTML usando DOMUtils
      return _parseGalleryHTML(htmlContent, galleryId);
    } catch (error) {
      print('Error fetching gallery $galleryId: $error');
      return null;
    }
  }

  Map<String, dynamic>? _parseGalleryHTML(String html, int galleryId) {
    try {
      final document = html_parser.parse(html);

      // Extraer título del h1 > a
      final titleElement = HtmlUtils.findElement(document, 'h1 a');
      final title = titleElement != null
          ? HtmlUtils.getTextContent(titleElement).trim()
          : 'Gallery $galleryId';

      // Extraer link principal del h1 > a
      final linkElement = HtmlUtils.findElement(document, 'h1 a');
      final relativeLink = linkElement?.attributes['href'];
      final link = relativeLink != null
          ? '$_baseUrl$relativeLink'
          : '$_baseUrl/galleries/$galleryId.html';

      // Extraer imagen thumbnail con URLs correctas para manga y game CG
      String linkImage = '';

      // 1. Intentar extraer de source data-srcset (AVIF) - Soportar tanto manga como game CG
      var sourceElement = HtmlUtils.findElement(document, '.dj-img1 picture source');

      // Si no se encuentra, intentar con game CG
      if (sourceElement == null) {
        sourceElement = HtmlUtils.findElement(document, '.gg-img1 picture source');
      }

      if (sourceElement != null) {
        final dataSrcset = HtmlUtils.getAttribute(sourceElement, 'data-srcset');
        if (dataSrcset.isNotEmpty) {
          // Extraer la primera URL del srcset
          final urls = dataSrcset.split(',');
          if (urls.isNotEmpty) {
            var firstUrl = urls[0].trim().split(' ')[0];
            
            // Reemplazar el dominio si es necesario ANTES de agregar el protocolo
            if (firstUrl.contains('//tn.hitomi.la')) {
              firstUrl = firstUrl.replaceAll('//tn.hitomi.la', '//atn.gold-usergeneratedcontent.net');
            } else if (firstUrl.contains('tn.hitomi.la')) {
              firstUrl = firstUrl.replaceAll('tn.hitomi.la', 'atn.gold-usergeneratedcontent.net');
            }
            
            // Optimizar thumbnail: reemplazar avifbigtn por avifsmallbigtn
            if (firstUrl.contains('avifbigtn')) {
              firstUrl = firstUrl.replaceAll('avifbigtn', 'avifsmallbigtn');
            }
            
            // Ahora agregar el protocolo si es necesario
            if (firstUrl.startsWith('//')) {
              linkImage = 'https:$firstUrl';
            } else if (firstUrl.startsWith('http')) {
              linkImage = firstUrl;
            }
          }
        }
      }

      // 2. Fallback: intentar con img data-src (WebP fallback) para ambos tipos
      if (linkImage.isEmpty) {
        var imgElement = HtmlUtils.findElement(document, '.dj-img1 picture img');
        if (imgElement == null) {
          imgElement = HtmlUtils.findElement(document, '.gg-img1 picture img');
        }
        if (imgElement != null) {
          var dataSrc = HtmlUtils.getAttribute(imgElement, 'data-src');
          if (dataSrc.isNotEmpty) {
            // Reemplazar el dominio si es necesario ANTES de agregar el protocolo
            if (dataSrc.contains('//tn.hitomi.la')) {
              dataSrc = dataSrc.replaceAll('//tn.hitomi.la', '//atn.gold-usergeneratedcontent.net');
            } else if (dataSrc.contains('tn.hitomi.la')) {
              dataSrc = dataSrc.replaceAll('tn.hitomi.la', 'atn.gold-usergeneratedcontent.net');
            }
            
            // Optimizar thumbnail: reemplazar avifbigtn por avifsmallbigtn
            if (dataSrc.contains('avifbigtn')) {
              dataSrc = dataSrc.replaceAll('avifbigtn', 'avifsmallbigtn');
            }
            
            // Ahora agregar el protocolo si es necesario
            if (dataSrc.startsWith('//')) {
              linkImage = 'https:$dataSrc';
            } else if (dataSrc.startsWith('http')) {
              linkImage = dataSrc;
            }
          }
        }
      }

      // Extraer tipo
      final typeElement = HtmlUtils.findElement(document, "table.dj-desc td a[href*='/type/']");
      final type = typeElement != null
          ? HtmlUtils.getTextContent(typeElement).trim()
          : 'doujinshi';

      // Extraer idioma
      final languageElement = HtmlUtils.findElement(document, "table.dj-desc td a[href*='spanish']");
      final language = languageElement != null ? 'spanish' : 'japanese';

      // Extraer artistas
      final artistElements = HtmlUtils.findElements(document, '.artist-list ul li a');
      final artists = <String>[];
      for (final element in artistElements) {
        final artist = HtmlUtils.getTextContent(element).trim();
        if (artist.isNotEmpty) {
          artists.add(artist);
        }
      }

      // Extraer tags
      final tagElements = HtmlUtils.findElements(document, '.relatedtags ul li a');
      final tags = <String>[];
      for (final element in tagElements) {
        final tag = HtmlUtils.getTextContent(element).trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }

      // Detectar fecha tanto para manga como game CG
      var dateElement = HtmlUtils.findElement(document, '.dj-date');
      if (dateElement == null) {
        dateElement = HtmlUtils.findElement(document, '.gg-date');
      }
      final date = dateElement != null
          ? HtmlUtils.getTextContent(dateElement).trim()
          : '';

      // Extraer series
      final seriesElements = HtmlUtils.findElements(document, '.series-list ul li a');
      final series = <String>[];
      for (final element in seriesElements) {
        final seriesName = HtmlUtils.getTextContent(element).trim();
        if (seriesName.isNotEmpty) {
          series.add(seriesName);
        }
      }

      return _formatGalleryData({
        'id': galleryId,
        'title': title,
        'link': link,
        'linkImage': linkImage,
        'type': type,
        'language': language,
        'artists': artists,
        'tags': tags,
        'series': series,
        'date': date,
        'files': [],
      });
    } catch (error) {
      print('Error parsing gallery HTML: $error');
      return null;
    }
  }

  Map<String, dynamic> _formatGalleryData(Map<String, dynamic> galleryData) {
    try {
      return {
        'id': galleryData['id'],
        'title': galleryData['title'] ?? 'Gallery ${galleryData['id']}',
        'link': galleryData['link'] ?? '$_baseUrl/galleries/${galleryData['id']}.html',
        'linkImage': galleryData['linkImage'] ?? '$_baseUrl/images/placeholder.jpg',
        'type': galleryData['type'] ?? 'doujinshi',
        'language': galleryData['language'] ?? 'spanish',
        'tags': galleryData['tags'] ?? [],
        'artists': galleryData['artists'] ?? [],
        'series': galleryData['series'] ?? [],
        'date': galleryData['date'] ?? '',
        'files': galleryData['files'] ?? [],
      };
    } catch (error) {
      print('Error formatting gallery data: $error');
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>?> getGallery(int galleryId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('https://ltn.gold-usergeneratedcontent.net/galleries/$galleryId.js'),
      );

      if (response.statusCode != 200) {
        print('Failed to fetch gallery JS: ${response.statusCode}');
        return null;
      }

      // La respuesta es un archivo JavaScript que define una variable 'galleryinfo'
      final jsContent = response.body;

      // Extraer la información de la galería del contenido JavaScript
      final galleryData = _parseGalleryJS(jsContent, galleryId);

      return galleryData;
    } catch (error) {
      print('Error fetching gallery data: $error');
      return null;
    }
  }

  Map<String, dynamic>? _parseGalleryJS(String jsContent, int galleryId) {
    try {
      print('Parsing JS content for gallery: $galleryId');
      final galleryinfoMatch = RegExp(r'var\s+galleryinfo\s*=\s*(\{.*?\}|\[.*?\]);?$', multiLine: true, dotAll: true)
          .firstMatch(jsContent);

      if (galleryinfoMatch == null || galleryinfoMatch.group(1) == null) {
        print('Could not find galleryinfo in JS content');
        return null;
      }

      final jsonData = json.decode(galleryinfoMatch.group(1)!);

      Map<String, dynamic> gallery;
      if (jsonData is List) {
        if (jsonData.isEmpty) {
          print('Gallery array is empty');
          return null;
        }
        gallery = jsonData[0];
      } else {
        gallery = jsonData;
      }

      if (gallery.isEmpty) {
        print('Gallery data is empty');
        return null;
      }

      return gallery;
    } catch (error) {
      print('Error parsing gallery JS: $error');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getGGData() async {
    try {
      // NO usar caché - siempre obtener valores frescos
      // Los valores b, o y los casos del switch son dinámicos
      final response = await _httpClient.get(
        Uri.parse('https://ltn.gold-usergeneratedcontent.net/gg.js'),
      );

      if (response.statusCode != 200) {
        print('Failed to fetch gg.js: ${response.statusCode}');
        return _cachedGGData; // Fallback a datos anteriores si falló
      }

      final jsContent = response.body;
      final ggData = _parseGGJS(jsContent);
      
      if (ggData != null) {
        _cachedGGData = ggData; // Solo para fallback en caso de error
      }
      
      return ggData;
    } catch (error) {
      print('Error fetching gg.js: $error');
      return _cachedGGData; // Fallback a datos anteriores si hubo error
    }
  }

  Map<String, dynamic>? _parseGGJS(String jsContent) {
    try {
      // Extraer el valor de 'b' (timestamp) - DINÁMICO, cambia cada ~30 min
      final bMatch = RegExp(r"b:\s*'([^']+)'").firstMatch(jsContent);
      if (bMatch == null || bMatch.group(1) == null) {
        print('Warning: Could not extract "b" value from gg.js');
        return null;
      }
      final String b = bMatch.group(1)!;

      // Extraer el valor inicial de 'o' DENTRO de la función m
      // Este valor es CRÍTICO y puede cambiar entre 0 y 1
      // var o = 0; → comportamiento: default=0, special=1
      // var o = 1; → comportamiento INVERTIDO: default=1, special=0
      final oInFunctionMatch = RegExp(r'm:\s*function[^{]*\{[^}]*?var\s+o\s*=\s*(\d+)', dotAll: true).firstMatch(jsContent);
      
      if (oInFunctionMatch == null) {
        print('Warning: Could not extract initial "o" value from m() function in gg.js');
        return null;
      }
      
      final int oInitial = int.parse(oInFunctionMatch.group(1)!);
      
      // Detectar el valor asignado en los casos del switch
      // Buscar "o = X; break;" dentro del switch
      final oSwitchMatch = RegExp(r'case\s+\d+:\s*(?:case\s+\d+:\s*)*o\s*=\s*(\d+);\s*break;', multiLine: true).firstMatch(jsContent);
      final int? oSwitchValue = oSwitchMatch != null ? int.parse(oSwitchMatch.group(1)!) : null;

      // Función 's' - subdirectory from hash (convierte últimos 3 chars hex a decimal)
      String Function(String) s = (String hash) {
        final match = RegExp(r'(..)(.)$').firstMatch(hash);
        if (match == null) return '0/';
        // Invertir los grupos y convertir de hex a decimal
        final hexValue = match.group(2)! + match.group(1)!;
        final decimalValue = int.parse(hexValue, radix: 16);
        return '$decimalValue/';
      };

      // Función 'm' - Determina el subdominio basándose en casos especiales
      // Parsear TODOS los casos del switch statement - DINÁMICO
      final Set<int> casesSet = {};
      final switchMatch = RegExp(r'switch\s*\(\s*g\s*\)\s*\{([\s\S]*?)\}', multiLine: true).firstMatch(jsContent);
      
      if (switchMatch == null) {
        print('Warning: Could not extract switch statement from gg.js');
        return null;
      }
      
      final switchContent = switchMatch.group(1) ?? '';
      // Buscar todos los números después de 'case'
      final casePattern = RegExp(r'case\s+(\d+):', multiLine: true);
      final cases = casePattern.allMatches(switchContent);
      
      for (final match in cases) {
        final caseNum = int.parse(match.group(1)!);
        casesSet.add(caseNum);
      }
      
      if (casesSet.isEmpty) {
        print('Warning: No special cases found in gg.js switch statement');
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('GG.js loaded with DYNAMIC values:');
      print('  ✓ b (timestamp): $b');
      print('  ✓ o_initial: $oInitial');
      print('  ✓ o_switch: ${oSwitchValue ?? "unknown"}');
      print('  ✓ Special cases: ${casesSet.length} cases');
      print('  ✓ Sample: ${casesSet.take(10).join(", ")}...');
      if (oInitial == 0) {
        print('  ⚙️  Logic: default=$oInitial, special=${oSwitchValue ?? 1}');
        print('  ⚙️  Normal behavior: default→a1/b1, special→a2/b2');
      } else {
        print('  ⚙️  Logic: default=$oInitial, special=${oSwitchValue ?? 0}');
        print('  ⚙️  INVERTED behavior: default→a2/b2, special→a1/b1');
      }
      print('  ⚙️  Formula: subdomain = 1 + m(g)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      int Function(int) m = (int g) {
        // Lógica extraída dinámicamente del gg.js:
        // var o = <oInitial>;  ← puede ser 0 o 1
        // switch (g) {
        //   case X: o = <oSwitchValue>; break;
        //   ... (casos variables, pueden cambiar)
        // }
        // return o;
        
        if (casesSet.contains(g)) {
          // Casos especiales retornan el valor del switch
          return oSwitchValue ?? (1 - oInitial); // Si no se detectó, asumir el opuesto de oInitial
        }
        
        return oInitial; // Casos normales retornan el valor inicial
      };

      return {
        'o': oInitial, // Valor inicial de 'o' en la función m
        'oSwitch': oSwitchValue, // Valor asignado en casos especiales
        'isInverted': oInitial == 1, // Flag para saber si está en modo invertido
        'b': b,
        's': s,
        'm': m,
        'casesCount': casesSet.length,
        'timestamp': DateTime.now().toIso8601String(), // Para debug
      };
    } catch (error) {
      print('❌ Error parsing gg.js: $error');
      return null;
    }
  }
}
