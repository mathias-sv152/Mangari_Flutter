import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class MangaReaderView extends StatefulWidget {
  final ChapterViewEntity chapter;
  final ServerEntity server;
  final String mangaTitle;
  final VoidCallback onBack;

  const MangaReaderView({
    super.key,
    required this.chapter,
    required this.server,
    required this.mangaTitle,
    required this.onBack,
  });

  @override
  State<MangaReaderView> createState() => _MangaReaderViewState();
}

class _MangaReaderViewState extends State<MangaReaderView> {
  ServersServiceV2? _serversService;
  
  List<String> _images = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  bool _showControls = true;
  
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  void _initializeService() async {
    try {
      print('🔍 MangaReaderView: Intentando obtener ServersServiceV2...');
      await Future.delayed(const Duration(milliseconds: 50));
      
      _serversService = getServersServiceSafely();
      
      if (_serversService != null) {
        print('✅ MangaReaderView: ServersServiceV2 obtenido correctamente');
        await _loadChapterImages();
      } else {
        print('❌ MangaReaderView: No se pudo obtener ServersServiceV2');
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo inicializar el servicio de servidores';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ MangaReaderView: Error en _initializeService: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inicializando servicios: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(true)  // Habilitar zoom nativo
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // WebView está listo
          },
        ),
      )
      ..addJavaScriptChannel(
        'PageTracker',
        onMessageReceived: (JavaScriptMessage message) {
          final pageData = jsonDecode(message.message);
          setState(() {
            _currentPage = pageData['currentPage'] ?? 0;
          });
        },
      )
      ..addJavaScriptChannel(
        'ToggleControls',
        onMessageReceived: (JavaScriptMessage message) {
          _toggleControls();
        },
      )
      ..addJavaScriptChannel(
        'Console',
        onMessageReceived: (JavaScriptMessage message) {
          print('WebView Console: ${message.message}');
        },
      );
  }

  Future<void> _loadChapterImages() async {
    if (_serversService == null) return;
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final images = await _serversService!.getChapterImagesFromServer(widget.server.id, widget.chapter.editorialLink);
      
      setState(() {
        _images = images;
        _isLoading = false;
      });

      // Cargar contenido HTML tan pronto como tengamos las imágenes
      if (_images.isNotEmpty) {
        _loadHtmlContent();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _loadHtmlContent() {
    final htmlContent = _generateHtmlContent();
    print('Loading HTML content with ${_images.length} images');
    _webViewController.loadHtmlString(htmlContent, baseUrl: 'https://mangadex.org/');
  }

  String _generateHtmlContent() {
    final imageElements = _images.asMap().entries.map((entry) {
      final index = entry.key;
      final imageUrl = entry.value;
      return '''
      <div class="image-container" data-index="$index">
        <img src="$imageUrl" alt="Manga page $index" class="manga-image" 
             onerror="this.style.display='none'; this.parentElement.querySelector('.loading-overlay').innerHTML='Error cargando imagen ${index + 1}'; this.parentElement.querySelector('.loading-overlay').style.color='red';"
             onload="console.log('Imagen ${index + 1} cargada correctamente'); this.parentElement.querySelector('.loading-overlay').style.display='none';" />
        <div class="loading-overlay">Cargando imagen ${index + 1}...</div>
      </div>
    ''';
    }).join('\n');

    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        
        body {
          background-color: black;
          display: flex;
          flex-direction: column;
          align-items: center;
          min-height: 100vh;
          overflow-x: hidden;
          touch-action: manipulation;
        }
        
        .image-container {
          width: 100%;
          display: flex;
          justify-content: center;
          margin-bottom: 2px;
          position: relative;
          min-height: 200px;
        }
        
        .manga-image {
          max-width: 100%;
          height: auto;
          display: block;
          image-rendering: -webkit-optimize-contrast;
          image-rendering: crisp-edges;
        }
        
        .loading-overlay {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          color: #bd93f9;
          background: rgba(0, 0, 0, 0.8);
          padding: 10px 20px;
          border-radius: 5px;
          font-family: Arial, sans-serif;
          display: block;
        }
        
        .image-loaded .loading-overlay {
          display: none;
        }
        
        .loading {
          color: white;
          text-align: center;
          padding: 20px;
          font-family: Arial, sans-serif;
        }
        
        .error {
          color: #ff5555;
          text-align: center;
          padding: 20px;
          font-family: Arial, sans-serif;
        }
      </style>
    </head>
    <body>
      $imageElements
      
      <script>
        let currentPage = 0;
        
        // Tracking de páginas
        function updateCurrentPage() {
          const images = document.querySelectorAll('.image-container');
          const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
          const windowHeight = window.innerHeight;
          
          for (let i = 0; i < images.length; i++) {
            const rect = images[i].getBoundingClientRect();
            const imageTop = rect.top + scrollTop;
            const imageBottom = imageTop + rect.height;
            
            if (imageTop <= scrollTop + windowHeight / 2 && imageBottom >= scrollTop + windowHeight / 2) {
              if (currentPage !== i) {
                currentPage = i;
                if (window.PageTracker) {
                  window.PageTracker.postMessage(JSON.stringify({
                    currentPage: currentPage,
                    totalPages: images.length
                  }));
                }
              }
              break;
            }
          }
        }
        
        // Event listeners
        window.addEventListener('scroll', updateCurrentPage);
        window.addEventListener('resize', updateCurrentPage);
        
        // Toggle controls on tap
        document.addEventListener('click', function(e) {
          if (window.ToggleControls) {
            window.ToggleControls.postMessage('toggle');
          }
        });
        
        // Prevent context menu
        document.addEventListener('contextmenu', function(e) {
          e.preventDefault();
        });
        
        // Initialize
        setTimeout(updateCurrentPage, 100);
        
        // Manejo de errores de imágenes
        document.querySelectorAll('.manga-image').forEach((img, index) => {
          const container = img.parentElement;
          
          img.addEventListener('load', function() {
            console.log('Image loaded:', index);
            container.classList.add('image-loaded');
            updateCurrentPage();
          });
          
          img.addEventListener('error', function() {
            console.log('Image error:', index);
            container.innerHTML = '<div class="error">Error al cargar imagen ' + (index + 1) + '</div>';
          });
          
          // Configurar headers manualmente usando fetch si es necesario
          if (img.src.includes('mangadex.org')) {
            // Para MangaDex, intentar cargar con fetch primero
            fetch(img.src, {
              method: 'GET',
              headers: {
                'Referer': 'https://mangadex.org/',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
              }
            }).then(response => {
              if (response.ok) {
                return response.blob();
              }
              throw new Error('Network response was not ok');
            }).then(blob => {
              const objectURL = URL.createObjectURL(blob);
              img.src = objectURL;
            }).catch(error => {
              console.error('Error loading image:', error);
              img.style.display = 'none';
              container.innerHTML = '<div class="error">Error al cargar imagen ' + (index + 1) + '</div>';
            });
          }
        });
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showControls ? AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mangaTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.chapter.chapterTitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_images.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentPage + 1}/${_images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ) : null,
      body: Stack(
        children: [
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: DraculaTheme.purple),
            SizedBox(height: 16),
            Text(
              'Cargando imágenes...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: DraculaTheme.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar las imágenes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DraculaTheme.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadChapterImages,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text(
          'No hay imágenes disponibles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    // WebView con el contenido HTML
    return WebViewWidget(controller: _webViewController);
  }
}