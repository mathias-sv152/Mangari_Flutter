import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

enum ImageLoadState {
  loading,
  loaded,
  error,
  retrying,
}

class ImageState {
  final String url;
  ImageLoadState state;
  int retryCount;
  String? errorMessage;

  ImageState({
    required this.url,
    this.state = ImageLoadState.loading,
    this.retryCount = 0,
    this.errorMessage,
  });
}

class MangaReaderView extends StatefulWidget {
  final ChapterViewEntity chapter;
  final ServerEntity server;
  final String mangaTitle;
  final String referer;
  final VoidCallback onBack;

  const MangaReaderView({
    super.key,
    required this.chapter,
    required this.server,
    required this.mangaTitle,
    required this.referer,
    required this.onBack,
  });

  @override
  State<MangaReaderView> createState() => _MangaReaderViewState();
}

class _MangaReaderViewState extends State<MangaReaderView> {
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;
  
  ServersServiceV2? _serversService;
  
  List<String> _images = [];
  Map<int, ImageState> _imageStates = {};
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
        'ImageLoaded',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          _handleImageLoaded(data['index']);
        },
      )
      ..addJavaScriptChannel(
        'ImageError',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          _handleImageError(data['index'], data['error']);
        },
      )
      ..addJavaScriptChannel(
        'RetryImage',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          _retryImageManually(data['index']);
        },
      )
      ..addJavaScriptChannel(
        'Console',
        onMessageReceived: (JavaScriptMessage message) {
          print('WebView Console: ${message.message}');
        },
      );
  }

  void _handleImageLoaded(int index) {
    if (mounted && _imageStates.containsKey(index)) {
      setState(() {
        _imageStates[index]!.state = ImageLoadState.loaded;
        _imageStates[index]!.retryCount = 0;
        _imageStates[index]!.errorMessage = null;
      });
      print('✅ Imagen $index cargada correctamente');
    }
  }

  void _handleImageError(int index, String error) {
    if (!mounted || !_imageStates.containsKey(index)) return;
    
    final imageState = _imageStates[index]!;
    
    print('❌ Error en imagen $index: $error (intento ${imageState.retryCount + 1}/$maxRetries)');
    
    if (imageState.retryCount < maxRetries) {
      // Retry automático
      setState(() {
        imageState.state = ImageLoadState.retrying;
        imageState.retryCount++;
        imageState.errorMessage = 'Reintentando... (${imageState.retryCount}/$maxRetries)';
      });
      
      // Esperar antes de reintentar
      Future.delayed(Duration(milliseconds: retryDelayMs * imageState.retryCount), () {
        if (mounted) {
          _retryImageLoad(index);
        }
      });
    } else {
      // Falló después de todos los intentos
      setState(() {
        imageState.state = ImageLoadState.error;
        imageState.errorMessage = 'Error después de $maxRetries intentos';
      });
    }
  }

  void _retryImageLoad(int index) {
    if (!mounted || !_imageStates.containsKey(index)) return;
    
    print('🔄 Reintentando carga de imagen $index...');
    
    final script = '''
      (function() {
        const container = document.querySelector('[data-index="$index"]');
        if (!container) return;
        
        const img = container.querySelector('img');
        const overlay = container.querySelector('.loading-overlay');
        
        if (img && overlay) {
          overlay.textContent = 'Reintentando... (${_imageStates[index]!.retryCount}/$maxRetries)';
          overlay.style.display = 'block';
          overlay.style.color = '#f1fa8c';
          
          // Forzar recarga
          const currentSrc = img.src;
          img.src = '';
          setTimeout(() => {
            img.src = currentSrc + '?retry=' + Date.now();
          }, 100);
        }
      })();
    ''';
    
    _webViewController.runJavaScript(script);
  }

  void _retryImageManually(int index) {
    if (!mounted || !_imageStates.containsKey(index)) return;
    
    print('🔄 Retry manual de imagen $index');
    
    setState(() {
      _imageStates[index]!.state = ImageLoadState.loading;
      _imageStates[index]!.retryCount = 0;
      _imageStates[index]!.errorMessage = null;
    });
    
    _retryImageLoad(index);
  }

  void _retryAllFailedImages() {
    final failedImages = _imageStates.entries
        .where((entry) => entry.value.state == ImageLoadState.error)
        .map((entry) => entry.key)
        .toList();
    
    if (failedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay imágenes con errores'),
          backgroundColor: DraculaTheme.green,
        ),
      );
      return;
    }
    
    print('🔄 Reintentando ${failedImages.length} imágenes fallidas...');
    
    for (final index in failedImages) {
      _retryImageManually(index);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reintentando ${failedImages.length} imagen(es)...'),
        backgroundColor: DraculaTheme.purple,
      ),
    );
  }

  Future<void> _loadChapterImages() async {
    if (_serversService == null) return;
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _imageStates.clear();
      });

      print('🔍 MangaReaderView: Usando servidor ${widget.server.id} con referer ${widget.referer}');

      final images = await _serversService!.getChapterImagesFromServer(widget.server.id, widget.chapter.editorialLink);
      
      setState(() {
        _images = images;
        _isLoading = false;
        
        // Inicializar estados de imágenes
        for (int i = 0; i < images.length; i++) {
          _imageStates[i] = ImageState(url: images[i]);
        }
      });

      // Cargar contenido HTML tan pronto como tengamos las imágenes
      if (_images.isNotEmpty) {
        _loadHtmlContent();
        // Inyectar el JavaScript para interceptar las peticiones de imágenes
        _injectImageInterceptor();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _injectImageInterceptor() {
    // Inyectar JavaScript para manejar la carga de imágenes con el referer correcto
    final script = '''
      (function() {
        const originalImage = window.Image;
        window.Image = function() {
          const img = new originalImage();
          const originalSrc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
          
          Object.defineProperty(img, 'src', {
            get: function() {
              return originalSrc.get.call(this);
            },
            set: function(value) {
              this.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
              originalSrc.set.call(this, value);
            }
          });
          
          return img;
        };
      })();
    ''';
    
    _webViewController.runJavaScript(script);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _loadHtmlContent() {
    final htmlContent = _generateHtmlContent();
    print('Loading HTML content with ${_images.length} images');
    print('🔍 Using referer: ${widget.referer}');
    _webViewController.loadHtmlString(htmlContent, baseUrl: widget.referer);
  }

  String _generateHtmlContent() {
    final imageElements = _images.asMap().entries.map((entry) {
      final index = entry.key;
      final imageUrl = entry.value;
      return '''
      <div class="image-container" data-index="$index">
        <img src="$imageUrl" 
             alt="Manga page $index" 
             class="manga-image"
             referrerpolicy="origin"
             loading="lazy"
             data-retry-count="0"
             onerror="handleImageError(this, $index)"
             onload="handleImageLoad(this, $index)" />
        <div class="loading-overlay">
          <div class="loading-text">Cargando imagen ${index + 1}...</div>
          <div class="loading-spinner"></div>
        </div>
        <div class="error-overlay" style="display: none;">
          <div class="error-icon">⚠️</div>
          <div class="error-text">Error cargando imagen ${index + 1}</div>
          <button class="retry-button" onclick="retryImage($index)">
            🔄 Reintentar
          </button>
        </div>
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
          background-color: #000;
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
          background: #1a1a1a;
        }
        
        .manga-image {
          max-width: 100%;
          height: auto;
          display: block;
          image-rendering: -webkit-optimize-contrast;
          image-rendering: crisp-edges;
          opacity: 0;
          transition: opacity 0.3s ease-in-out;
        }
        
        .manga-image.loaded {
          opacity: 1;
        }
        
        .loading-overlay {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          color: #bd93f9;
          background: rgba(0, 0, 0, 0.9);
          padding: 20px 30px;
          border-radius: 10px;
          font-family: Arial, sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 10px;
        }
        
        .loading-text {
          font-size: 14px;
        }
        
        .loading-spinner {
          width: 30px;
          height: 30px;
          border: 3px solid rgba(189, 147, 249, 0.3);
          border-top-color: #bd93f9;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
        
        .error-overlay {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          color: #ff5555;
          background: rgba(0, 0, 0, 0.95);
          padding: 20px 30px;
          border-radius: 10px;
          font-family: Arial, sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 15px;
          border: 2px solid #ff5555;
        }
        
        .error-icon {
          font-size: 48px;
        }
        
        .error-text {
          font-size: 14px;
          text-align: center;
        }
        
        .retry-button {
          background: #bd93f9;
          color: #000;
          border: none;
          padding: 10px 20px;
          border-radius: 5px;
          font-size: 14px;
          font-weight: bold;
          cursor: pointer;
          transition: background 0.2s;
        }
        
        .retry-button:active {
          background: #9580d6;
        }
        
        .image-loaded .loading-overlay {
          display: none;
        }
        
        .retrying .loading-overlay {
          color: #f1fa8c;
        }
        
        .retrying .loading-spinner {
          border-top-color: #f1fa8c;
          border-color: rgba(241, 250, 140, 0.3);
        }
      </style>
    </head>
    <body>
      $imageElements
      
      <script>
        let currentPage = 0;
        const MAX_RETRIES = $maxRetries;
        
        // Manejo de carga de imagen
        function handleImageLoad(img, index) {
          console.log('✅ Imagen ' + index + ' cargada correctamente');
          img.classList.add('loaded');
          img.parentElement.classList.add('image-loaded');
          img.parentElement.querySelector('.loading-overlay').style.display = 'none';
          
          if (window.ImageLoaded) {
            window.ImageLoaded.postMessage(JSON.stringify({
              index: index
            }));
          }
        }
        
        // Manejo de error de imagen
        function handleImageError(img, index) {
          const container = img.parentElement;
          const retryCount = parseInt(img.getAttribute('data-retry-count') || '0');
          
          console.log('❌ Error en imagen ' + index + ' (intento ' + (retryCount + 1) + '/' + MAX_RETRIES + ')');
          
          if (retryCount < MAX_RETRIES) {
            // Retry automático
            img.setAttribute('data-retry-count', (retryCount + 1).toString());
            container.classList.add('retrying');
            container.querySelector('.loading-overlay').style.display = 'flex';
            container.querySelector('.loading-text').textContent = 
              'Reintentando... (' + (retryCount + 1) + '/' + MAX_RETRIES + ')';
            
            if (window.ImageError) {
              window.ImageError.postMessage(JSON.stringify({
                index: index,
                error: 'Load failed',
                retryCount: retryCount + 1
              }));
            }
          } else {
            // Mostrar error después de todos los intentos
            container.querySelector('.loading-overlay').style.display = 'none';
            container.querySelector('.error-overlay').style.display = 'flex';
            
            if (window.ImageError) {
              window.ImageError.postMessage(JSON.stringify({
                index: index,
                error: 'Failed after ' + MAX_RETRIES + ' retries',
                retryCount: retryCount
              }));
            }
          }
        }
        
        // Retry manual de imagen
        function retryImage(index) {
          console.log('🔄 Retry manual de imagen ' + index);
          
          const container = document.querySelector('[data-index="' + index + '"]');
          if (!container) return;
          
          const img = container.querySelector('img');
          const errorOverlay = container.querySelector('.error-overlay');
          const loadingOverlay = container.querySelector('.loading-overlay');
          
          // Resetear estado
          img.setAttribute('data-retry-count', '0');
          container.classList.remove('retrying', 'image-loaded');
          errorOverlay.style.display = 'none';
          loadingOverlay.style.display = 'flex';
          loadingOverlay.querySelector('.loading-text').textContent = 'Cargando imagen ' + (index + 1) + '...';
          img.classList.remove('loaded');
          
          if (window.RetryImage) {
            window.RetryImage.postMessage(JSON.stringify({
              index: index
            }));
          }
        }
        
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
        
        // Toggle controls on tap (excepto en botones)
        document.addEventListener('click', function(e) {
          if (!e.target.classList.contains('retry-button')) {
            if (window.ToggleControls) {
              window.ToggleControls.postMessage('toggle');
            }
          }
        });
        
        // Prevent context menu
        document.addEventListener('contextmenu', function(e) {
          e.preventDefault();
        });
        
        // Initialize
        setTimeout(updateCurrentPage, 100);
        
        console.log('📱 Manga Reader inicializado');
        console.log('🔗 Referer: ${widget.referer}');
        console.log('📄 Total de páginas: ${_images.length}');
        console.log('🔄 Max retries: ' + MAX_RETRIES);
      </script>
    </body>
    </html>
    ''';
  }

  int get _failedImagesCount {
    return _imageStates.values
        .where((state) => state.state == ImageLoadState.error)
        .length;
  }

  int get _loadedImagesCount {
    return _imageStates.values
        .where((state) => state.state == ImageLoadState.loaded)
        .length;
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
          if (_images.isNotEmpty) ...[
            if (_failedImagesCount > 0)
              IconButton(
                icon: Badge(
                  label: Text(_failedImagesCount.toString()),
                  backgroundColor: DraculaTheme.red,
                  child: const Icon(Icons.refresh, color: DraculaTheme.red),
                ),
                onPressed: _retryAllFailedImages,
                tooltip: 'Reintentar imágenes fallidas',
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_currentPage + 1}/${_images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_loadedImagesCount < _images.length)
                      Text(
                        '$_loadedImagesCount cargadas',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
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