import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

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
  
  InAppWebViewController? _webViewController;
  
  // Cliente HTTP reutilizable con timeout
  late final http.Client _httpClient;
  
  // Cache de imágenes en memoria para evitar múltiples descargas
  final Map<String, Uint8List> _imageCache = {};
  
  // Debouncing para updateCurrentPage
  DateTime _lastPageUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Inicializar cliente HTTP
    _httpClient = http.Client();
    
    // Configurar la UI del sistema para mostrar las barras inicialmente
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }
  
  @override
  void dispose() {
    // Limpiar recursos
    _httpClient.close();
    _imageCache.clear();
    _webViewController?.dispose();
    
    // Restaurar la UI del sistema al salir
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
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



  void _handleImageLoaded(int index) {
    if (!mounted || !_imageStates.containsKey(index)) return;
    
    // Actualizar estado sin setState si no es visible
    final imageState = _imageStates[index]!;
    if (imageState.state == ImageLoadState.loaded) return; // Ya cargada
    
    imageState.state = ImageLoadState.loaded;
    imageState.retryCount = 0;
    imageState.errorMessage = null;
    
    // Solo setState si es relevante para la UI (cerca de la página actual)
    if ((index - _currentPage).abs() <= 3) {
      setState(() {});
    }
  }

  void _handleImageError(int index, String error) {
    if (!mounted || !_imageStates.containsKey(index)) return;
    
    final imageState = _imageStates[index]!;
    
    if (imageState.retryCount < maxRetries) {
      // Retry automático
      imageState.state = ImageLoadState.retrying;
      imageState.retryCount++;
      imageState.errorMessage = 'Reintentando... (${imageState.retryCount}/$maxRetries)';
      _invalidateCountCache();
      
      // Solo setState si es visible
      if ((index - _currentPage).abs() <= 3) {
        setState(() {});
      }
      
      // Esperar antes de reintentar
      Future.delayed(Duration(milliseconds: retryDelayMs * imageState.retryCount), () {
        if (mounted) {
          _retryImageLoad(index);
        }
      });
    } else {
      // Falló después de todos los intentos
      imageState.state = ImageLoadState.error;
      imageState.errorMessage = 'Error después de $maxRetries intentos';
      _invalidateCountCache();
      
      if ((index - _currentPage).abs() <= 3) {
        setState(() {});
      }
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
    
    _webViewController?.evaluateJavascript(source: script);
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

      // Si el WebView ya está creado, cargar el contenido
      if (_webViewController != null && _images.isNotEmpty) {
        _loadHtmlContent();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _injectImageInterceptor() async {
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
    
    await _webViewController?.evaluateJavascript(source: script);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Controlar la visibilidad de la barra de estado del sistema
    if (_showControls) {
      // Mostrar barra de notificaciones
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    } else {
      // Ocultar barra de notificaciones (modo inmersivo)
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersive,
      );
    }
  }

  void _loadHtmlContent() {
    final htmlContent = _generateHtmlContent();
    print('Loading HTML content with ${_images.length} images');
    print('🔍 Using referer: ${widget.referer}');
    _webViewController?.loadData(data: htmlContent);
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
             loading="${index < 5 ? 'eager' : 'lazy'}"
             decoding="async"
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
          will-change: opacity;
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
          
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('ImageLoaded', JSON.stringify({
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
            
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('ImageError', JSON.stringify({
                index: index,
                error: 'Load failed',
                retryCount: retryCount + 1
              }));
            }
          } else {
            // Mostrar error después de todos los intentos
            container.querySelector('.loading-overlay').style.display = 'none';
            container.querySelector('.error-overlay').style.display = 'flex';
            
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('ImageError', JSON.stringify({
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
          
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('RetryImage', JSON.stringify({
              index: index
            }));
          }
        }
        
        // Usar Intersection Observer para tracking eficiente
        let updateTimeout = null;
        const observer = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting && entry.intersectionRatio > 0.5) {
              const index = parseInt(entry.target.getAttribute('data-index'));
              if (currentPage !== index) {
                currentPage = index;
                
                // Debounce updates
                if (updateTimeout) clearTimeout(updateTimeout);
                updateTimeout = setTimeout(() => {
                  if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('PageTracker', JSON.stringify({
                      currentPage: currentPage,
                      totalPages: document.querySelectorAll('.image-container').length
                    }));
                  }
                }, 100);
              }
            }
          });
        }, {
          threshold: [0.5],
          rootMargin: '0px'
        });
        
        // Observar todos los contenedores de imágenes
        document.querySelectorAll('.image-container').forEach(container => {
          observer.observe(container);
        });
        
        // Precargar imágenes cercanas cuando una imagen sea visible
        const preloadObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const index = parseInt(entry.target.getAttribute('data-index'));
              // Precargar 2 imágenes adelante
              for (let i = 1; i <= 2; i++) {
                const nextContainer = document.querySelector('[data-index=\"' + (index + i) + '\"]');
                if (nextContainer) {
                  const img = nextContainer.querySelector('img');
                  if (img && img.loading === 'lazy') {
                    img.loading = 'eager';
                  }
                }
              }
            }
          });
        }, { rootMargin: '200px' });
        
        document.querySelectorAll('.image-container').forEach(container => {
          preloadObserver.observe(container);
        });
        
        // Toggle controls on tap (excepto en botones)
        document.addEventListener('click', function(e) {
          if (!e.target.classList.contains('retry-button')) {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('ToggleControls', 'toggle');
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

  int? _cachedFailedCount;
  int? _cachedLoadedCount;
  
  int get _failedImagesCount {
    return _cachedFailedCount ??= _imageStates.values
        .where((state) => state.state == ImageLoadState.error)
        .length;
  }

  int get _loadedImagesCount {
    return _cachedLoadedCount ??= _imageStates.values
        .where((state) => state.state == ImageLoadState.loaded)
        .length;
  }
  
  void _invalidateCountCache() {
    _cachedFailedCount = null;
    _cachedLoadedCount = null;
  }

  void _navigateToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _images.length) return;
    
    final script = '''
      (function() {
        const container = document.querySelector('[data-index="$pageIndex"]');
        if (container) {
          container.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      })();
    ''';
    
    _webViewController?.evaluateJavascript(source: script);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBody(),
          _buildAnimatedAppBar(),
          _buildAnimatedBottomBar(),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return AnimatedSlide(
      offset: _showControls ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: kToolbarHeight + 10,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onBack,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  ),
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
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
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
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBottomBar() {
    if (_images.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: _showControls ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            color: Colors.black.withOpacity(0.75),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${_currentPage + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: DraculaTheme.purple,
                              inactiveTrackColor: DraculaTheme.purple.withOpacity(0.3),
                              thumbColor: DraculaTheme.purple,
                              overlayColor: DraculaTheme.purple.withOpacity(0.3),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                            ),
                            child: Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: (_images.length - 1).toDouble(),
                              divisions: _images.length - 1,
                              onChanged: (value) {
                                final newPage = value.round();
                                if (newPage != _currentPage) {
                                  setState(() {
                                    _currentPage = newPage;
                                  });
                                  _navigateToPage(newPage);
                                }
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${_images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

    // WebView con el contenido HTML usando InAppWebView
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        useHybridComposition: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: false,
        // Optimizaciones de rendimiento
        cacheEnabled: true,
        clearCache: false,
        disableContextMenu: true,
        minimumFontSize: 1,
        // Mejoras de carga de imágenes
        loadsImagesAutomatically: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        // Seguridad
        allowContentAccess: true,
        allowFileAccess: true,
        // IMPORTANTE: Habilitar interceptor de recursos
        useShouldInterceptRequest: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        
        // Agregar JavaScript handlers
        controller.addJavaScriptHandler(
          handlerName: 'PageTracker',
          callback: (args) {
            final now = DateTime.now();
            // Debouncing: solo actualizar si han pasado 100ms
            if (now.difference(_lastPageUpdate).inMilliseconds < 100) return;
            
            final message = args[0] as String;
            final pageData = jsonDecode(message);
            final newPage = pageData['currentPage'] ?? 0;
            
            if (_currentPage != newPage) {
              _lastPageUpdate = now;
              setState(() {
                _currentPage = newPage;
              });
            }
          },
        );
        
        controller.addJavaScriptHandler(
          handlerName: 'ToggleControls',
          callback: (args) {
            _toggleControls();
          },
        );
        
        controller.addJavaScriptHandler(
          handlerName: 'ImageLoaded',
          callback: (args) {
            final message = args[0] as String;
            final data = jsonDecode(message);
            _handleImageLoaded(data['index']);
          },
        );
        
        controller.addJavaScriptHandler(
          handlerName: 'ImageError',
          callback: (args) {
            final message = args[0] as String;
            final data = jsonDecode(message);
            _handleImageError(data['index'], data['error']);
          },
        );
        
        controller.addJavaScriptHandler(
          handlerName: 'RetryImage',
          callback: (args) {
            final message = args[0] as String;
            final data = jsonDecode(message);
            _retryImageManually(data['index']);
          },
        );
        
        controller.addJavaScriptHandler(
          handlerName: 'Console',
          callback: (args) {
            final message = args[0] as String;
            print('WebView Console: $message');
          },
        );
        
        // Cargar el contenido HTML después de configurar los handlers
        if (_images.isNotEmpty) {
          _loadHtmlContent();
        }
      },
      onLoadStop: (controller, url) async {
        // WebView terminó de cargar
        await _injectImageInterceptor();
      },
      onConsoleMessage: (controller, consoleMessage) {
        print('WebView Console: ${consoleMessage.message}');
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        
        // Solo interceptar imágenes de manga
        if (!_images.any((imageUrl) => url.contains(imageUrl) || imageUrl.contains(url))) {
          return null;
        }
        
        try {
          // Verificar cache primero
          if (_imageCache.containsKey(url)) {
            return WebResourceResponse(
              contentType: 'image/jpeg',
              data: _imageCache[url]!,
              statusCode: 200,
            );
          }
          
          // Realizar petición con timeout y el cliente reutilizable
          final response = await _httpClient
              .get(
                Uri.parse(url),
                headers: {
                  'Referer': widget.referer,
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                },
              )
              .timeout(const Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            // Cachear solo si el tamaño es razonable (< 5MB)
            if (response.bodyBytes.length < 5 * 1024 * 1024) {
              _imageCache[url] = Uint8List.fromList(response.bodyBytes);
              
              // Limitar cache a 50 imágenes para evitar OOM
              if (_imageCache.length > 50) {
                final firstKey = _imageCache.keys.first;
                _imageCache.remove(firstKey);
              }
            }
            
            return WebResourceResponse(
              contentType: response.headers['content-type'] ?? 'image/jpeg',
              data: response.bodyBytes,
              statusCode: response.statusCode,
            );
          }
        } catch (e) {
          // Silenciar errores de timeout/network - dejar que el retry maneje
        }
        
        return null;
      },
    );
  }
}