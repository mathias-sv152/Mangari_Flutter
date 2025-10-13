import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/infrastructure/database/database_service.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

enum ImageLoadState { loading, loaded, error, retrying }

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
  final String mangaId;
  final String referer;
  final VoidCallback onBack;

  const MangaReaderView({
    super.key,
    required this.chapter,
    required this.server,
    required this.mangaTitle,
    required this.mangaId,
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
  DatabaseService? _databaseService;

  List<String> _images = [];
  Map<int, ImageState> _imageStates = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  bool _showControls = true;

  InAppWebViewController? _webViewController;

  // Cliente HTTP reutilizable con timeout
  late final http.Client _httpClient;

  // Timer para guardar progreso periódicamente
  Timer? _progressSaveTimer;

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
    // Guardar progreso final antes de salir
    _saveReadingProgress();

    // Cancelar timer
    _progressSaveTimer?.cancel();

    // Limpiar recursos
    _httpClient.close();
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
      _databaseService = DatabaseService();

      if (_serversService != null) {
        print('✅ MangaReaderView: ServersServiceV2 obtenido correctamente');
        await _loadChapterImages();
        await _loadReadingProgress();
        _startProgressSaveTimer();
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

  // ========== GESTIÓN DE PROGRESO DE LECTURA ==========

  /// Carga el progreso de lectura guardado
  Future<void> _loadReadingProgress() async {
    if (_databaseService == null || _images.isEmpty) return;

    try {
      final progress = await _databaseService!.getReadingProgress(
        mangaId: widget.mangaId,
        serverId: widget.server.id,
        chapterId: widget.chapter.editorialLink,
        editorial: widget.chapter.editorialName,
      );

      if (progress != null && mounted) {
        final savedPage = progress['current_page'] as int;
        print(
          '📖 Progreso cargado: página $savedPage de ${progress['total_pages']}',
        );

        if (savedPage > 0 && savedPage < _images.length) {
          // Actualizar el estado ANTES de cargar el HTML
          _currentPage = savedPage;
          print('✅ Página inicial configurada: $_currentPage');
        }
      } else {
        print('ℹ️ No hay progreso guardado, iniciando en página 0');
      }

      // Ahora sí cargar el HTML con el _currentPage correcto
      if (_webViewController != null && _images.isNotEmpty) {
        print('🔄 Cargando HTML con página inicial: $_currentPage');
        _loadHtmlContent();
      }
    } catch (e) {
      print('❌ Error cargando progreso de lectura: $e');
      // Incluso si hay error, cargar el HTML
      if (_webViewController != null && _images.isNotEmpty) {
        _loadHtmlContent();
      }
    }
  }

  /// Guarda el progreso de lectura actual
  Future<void> _saveReadingProgress() async {
    if (_databaseService == null || _images.isEmpty) return;

    try {
      await _databaseService!.saveReadingProgress(
        mangaId: widget.mangaId,
        serverId: widget.server.id,
        chapterId: widget.chapter.editorialLink,
        chapterTitle: widget.chapter.chapterTitle,
        editorial: widget.chapter.editorialName,
        currentPage: _currentPage,
        totalPages: _images.length,
      );

      print('💾 Progreso guardado: página $_currentPage de ${_images.length}');
    } catch (e) {
      print('❌ Error guardando progreso: $e');
    }
  }

  /// Inicia un timer para guardar el progreso periódicamente
  void _startProgressSaveTimer() {
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveReadingProgress();
    });
  }

  /// Actualiza el progreso cuando cambia la página actual (solo desde el slider)
  void _updateCurrentPageProgress(int newPage) {
    if (_currentPage == newPage) return;

    setState(() {
      _currentPage = newPage;
    });

    // Guardar progreso después de un pequeño delay para evitar guardados excesivos
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_currentPage == newPage) {
        _saveReadingProgress();

        // Si llegó a la última página, marcar como completado
        if (newPage >= _images.length - 1) {
          _markChapterAsCompleted();
        }
      }
    });
  }

  /// Marca el capítulo como completado
  Future<void> _markChapterAsCompleted() async {
    if (_databaseService == null) return;

    try {
      await _databaseService!.markChapterAsCompleted(
        mangaId: widget.mangaId,
        serverId: widget.server.id,
        chapterId: widget.chapter.editorialLink,
        chapterTitle: widget.chapter.chapterTitle,
        editorial: widget.chapter.editorialName,
        totalPages: _images.length,
      );

      print('✅ Capítulo marcado como completado');
    } catch (e) {
      print('❌ Error marcando capítulo como completado: $e');
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
      imageState.errorMessage =
          'Reintentando... (${imageState.retryCount}/$maxRetries)';
      _invalidateCountCache();

      // Solo setState si es visible
      if ((index - _currentPage).abs() <= 3) {
        setState(() {});
      }

      // Esperar antes de reintentar
      Future.delayed(
        Duration(milliseconds: retryDelayMs * imageState.retryCount),
        () {
          if (mounted) {
            _retryImageLoad(index);
          }
        },
      );
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
    final failedImages =
        _imageStates.entries
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

      print(
        '🔍 MangaReaderView: Usando servidor ${widget.server.id} con referer ${widget.referer}',
      );

      final images = await _serversService!.getChapterImagesFromServer(
        widget.server.id,
        widget.chapter.editorialLink,
      );

      setState(() {
        _images = images;
        _isLoading = false;

        // Inicializar estados de imágenes
        for (int i = 0; i < images.length; i++) {
          _imageStates[i] = ImageState(url: images[i]);
        }
      });

      print('✅ Imágenes cargadas: ${images.length}');
      // NO cargar HTML aquí, esperar a que _loadReadingProgress configure _currentPage
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
  }

  void _loadHtmlContent() {
    if (_webViewController == null) {
      print('⚠️ WebView no está listo aún, esperando...');
      return;
    }

    if (_images.isEmpty) {
      print('⚠️ No hay imágenes cargadas aún, esperando...');
      return;
    }

    final htmlContent = _generateHtmlContent();
    print(
      '🔄 Cargando HTML con ${_images.length} imágenes, página inicial: $_currentPage',
    );
    print('🔍 Usando referer: ${widget.referer}');
    _webViewController?.loadData(data: htmlContent);
  }

  String _generateHtmlContent() {
    final imageElements = _images
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final imageUrl = entry.value;

          // Calcular la prioridad de carga basada en la distancia a la página actual
          final distance = (index - _currentPage).abs();
          String loadingStrategy;

          if (distance <= 2) {
            // Páginas muy cercanas: carga inmediata
            loadingStrategy = 'eager';
          } else if (distance <= 5) {
            // Páginas cercanas: carga automática pero con menor prioridad
            loadingStrategy = 'auto';
          } else {
            // Páginas lejanas: carga solo cuando sea necesario
            loadingStrategy = 'lazy';
          }

          return '''
      <div class="image-container" data-index="$index">
        <img src="$imageUrl" 
             alt="Manga page $index" 
             class="manga-image"
             referrerpolicy="origin"
             loading="$loadingStrategy"
             decoding="async"
             data-retry-count="0"
             data-distance="$distance"
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
        })
        .join('\n');

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
          visibility: hidden;
          opacity: 0;
          transition: opacity 0.4s ease-in-out;
        }
        
        body.ready {
          visibility: visible;
          opacity: 1;
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
        let currentPage = $_currentPage;
        const MAX_RETRIES = $maxRetries;
        let pageTrackerEnabled = false;  // Deshabilitar tracker hasta que se complete navegación inicial
        let criticalImagesLoaded = new Set();  // Track de imágenes críticas cargadas
        let contentShown = false;  // Flag para saber si ya se mostró el contenido
        
        // Verificar si las imágenes críticas están cargadas
        function checkCriticalImagesLoaded() {
          if (contentShown) return;
          
          const targetPage = currentPage;
          const criticalPages = [targetPage - 1, targetPage, targetPage + 1].filter(p => p >= 0 && p < ${_images.length});
          
          // Verificar si todas las páginas críticas están cargadas
          const allCriticalLoaded = criticalPages.every(page => criticalImagesLoaded.has(page));
          
          if (allCriticalLoaded) {
            showContent();
            contentShown = true;
          }
        }
        
        // Manejo de carga de imagen (optimizado - menos logs)
        function handleImageLoad(img, index) {
          img.classList.add('loaded');
          img.parentElement.classList.add('image-loaded');
          img.parentElement.querySelector('.loading-overlay').style.display = 'none';
          
          // Marcar como cargada y verificar si es crítica
          criticalImagesLoaded.add(index);
          checkCriticalImagesLoaded();
          
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('ImageLoaded', JSON.stringify({
              index: index
            }));
          }
        }
        
        // Manejo de error de imagen (optimizado)
        function handleImageError(img, index) {
          const container = img.parentElement;
          const retryCount = parseInt(img.getAttribute('data-retry-count') || '0');
          
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
        
        // Función para actualizar prioridades de carga basadas en la página actual
        function updateLoadingPriorities(centerPage) {
          const allImages = document.querySelectorAll('.manga-image');
          
          // Optimización: usar fragment para cambios batch
          allImages.forEach(img => {
            const container = img.parentElement;
            const imgIndex = parseInt(container.getAttribute('data-index'));
            const distance = Math.abs(imgIndex - centerPage);
            
            // Actualizar estrategia de carga basada en distancia
            if (distance <= 2) {
              // Imágenes muy cercanas: forzar carga inmediata
              if (img.loading !== 'eager') {
                img.loading = 'eager';
                // Si la imagen no ha empezado a cargar, forzar reload
                if (!img.complete && !img.src) {
                  img.src = img.getAttribute('src') || '';
                }
              }
            } else if (distance <= 5) {
              // Imágenes cercanas: permitir carga automática
              if (img.loading === 'lazy') {
                img.loading = 'auto';
              }
            } else if (distance > 10) {
              // Imágenes lejanas: postponer carga
              if (img.loading === 'eager' || img.loading === 'auto') {
                img.loading = 'lazy';
              }
            }
          });
        }
        
        // Usar Intersection Observer para tracking eficiente de página actual
        const pageTracker = new IntersectionObserver((entries) => {
          // Si el tracker está deshabilitado, ignorar
          if (!pageTrackerEnabled) {
            return;
          }
          
          // Buscar la entrada más visible
          let mostVisible = null;
          let maxRatio = 0;
          
          entries.forEach(entry => {
            const index = parseInt(entry.target.getAttribute('data-index'));
            
            // Considerar entrada si está intersectando
            if (entry.isIntersecting && entry.intersectionRatio >= maxRatio) {
              maxRatio = entry.intersectionRatio;
              mostVisible = index;
            }
          });
          
          // Actualizar si encontramos una página visible y es diferente
          if (mostVisible !== null && currentPage !== mostVisible) {
            currentPage = mostVisible;
            
            // Notificar inmediatamente a Flutter
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('PageTracker', JSON.stringify({
                currentPage: currentPage,
                totalPages: document.querySelectorAll('.image-container').length
              }));
            }
          }
        }, {
          // Reducir thresholds para mejor performance
          threshold: [0, 0.25, 0.5, 0.75, 1.0],
          // Sin margen para que solo cuente lo visible en pantalla
          rootMargin: '0px'
        });
        
        // Observar todos los contenedores de imágenes para tracking
        const containers = document.querySelectorAll('.image-container');
        containers.forEach(container => {
          pageTracker.observe(container);
        });
        
        // Precargar imágenes cercanas cuando una imagen sea visible (optimizado)
        const preloadObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const index = parseInt(entry.target.getAttribute('data-index'));
              
              // Actualizar prioridades de carga centradas en esta página
              updateLoadingPriorities(index);
              
              // Precargar solo 2 imágenes adelante y 1 atrás (reducido para performance)
              for (let i = -1; i <= 2; i++) {
                if (i === 0) continue;
                
                const targetIndex = index + i;
                const targetContainer = document.querySelector('[data-index="' + targetIndex + '"]');
                
                if (targetContainer) {
                  const img = targetContainer.querySelector('img');
                  if (img && !img.complete && img.loading !== 'eager') {
                    img.loading = 'eager';
                  }
                }
              }
            }
          });
        }, { 
          rootMargin: '200px', // Reducido de 300px a 200px
          threshold: [0] // Solo trigger cuando comienza a aparecer
        });
        
        containers.forEach(container => {
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
        
        // Función para mostrar el contenido después del scroll inicial
        function showContent() {
          if (contentShown) return;
          document.body.classList.add('ready');
          contentShown = true;
        }
        
        // Timeout de seguridad: mostrar contenido después de 2.5 segundos máximo
        setTimeout(() => {
          if (!contentShown) showContent();
        }, 2500);
        
        // Inicializar prioridades de carga basadas en la página inicial
        function initializeLoadingPriorities() {
          const initialPage = currentPage || 0;
          updateLoadingPriorities(initialPage);
        }
        
        // Esperar a que el DOM esté listo (optimizado)
        if (document.readyState === 'complete') {
          requestAnimationFrame(initializeLoadingPriorities);
        } else {
          window.addEventListener('load', () => {
            requestAnimationFrame(initializeLoadingPriorities);
          });
        }
      </script>
    </body>
    </html>
    ''';
  }

  int? _cachedFailedCount;
  int? _cachedLoadedCount;

  int get _failedImagesCount {
    return _cachedFailedCount ??=
        _imageStates.values
            .where((state) => state.state == ImageLoadState.error)
            .length;
  }

  int get _loadedImagesCount {
    return _cachedLoadedCount ??=
        _imageStates.values
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
        // Asegurar que el tracker esté habilitado para navegación manual
        pageTrackerEnabled = true;
        
        const container = document.querySelector('[data-index="$pageIndex"]');
        if (container) {
          container.scrollIntoView({ behavior: 'smooth', block: 'start' });
          // Actualizar prioridades de carga
          if (typeof updateLoadingPriorities === 'function') {
            updateLoadingPriorities($pageIndex);
          }
        }
      })();
    ''';

    _webViewController?.evaluateJavascript(source: script);
  }

  void _navigateToPageInstantly(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _images.length) return;

    print('🚀 Navegando instantáneamente a página $pageIndex');

    final script = '''
      (function() {
        // Deshabilitar tracker temporalmente
        pageTrackerEnabled = false;
        
        const container = document.querySelector('[data-index="$pageIndex"]');
        if (container) {
          // Hacer scroll instantáneo (invisible para el usuario porque body está oculto)
          container.scrollIntoView({ behavior: 'instant', block: 'start' });
          
          // Forzar actualización del tracker
          currentPage = $pageIndex;
          
          // Actualizar prioridades de carga inmediatamente
          if (typeof updateLoadingPriorities === 'function') {
            updateLoadingPriorities($pageIndex);
          }
          
          // Notificar a Flutter del cambio
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('PageTracker', JSON.stringify({
              currentPage: $pageIndex,
              totalPages: document.querySelectorAll('.image-container').length
            }));
          }
          
          // Después del scroll, verificar si las imágenes críticas ya están listas
          setTimeout(checkCriticalImagesLoaded, 100);
          
          // Habilitar tracker después de que todo esté listo
          setTimeout(function() {
            pageTrackerEnabled = true;
          }, 500);
        } else {
          // Mostrar contenido incluso si hay error (no esperar imágenes)
          setTimeout(showContent, 100);
          pageTrackerEnabled = true;
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
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.75)),
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
                          child: const Icon(
                            Icons.refresh,
                            color: DraculaTheme.red,
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                              inactiveTrackColor: DraculaTheme.purple
                                  .withOpacity(0.3),
                              thumbColor: DraculaTheme.purple,
                              overlayColor: DraculaTheme.purple.withOpacity(
                                0.3,
                              ),
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
                                  _updateCurrentPageProgress(newPage);
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
              style: TextStyle(color: Colors.white, fontSize: 16),
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
          style: TextStyle(color: Colors.white, fontSize: 16),
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
        // 🚀 Optimizaciones de rendimiento - CACHE DESHABILITADA
        cacheEnabled: false,
        clearCache: true,
        disableContextMenu: true,
        minimumFontSize: 1,
        // Mejoras de carga de imágenes
        loadsImagesAutomatically: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        // Deshabilitar recursos innecesarios para mejor performance
        javaScriptCanOpenWindowsAutomatically: false,
        horizontalScrollBarEnabled: false,
        // Seguridad
        allowContentAccess: true,
        allowFileAccess: true,
        // IMPORTANTE: Habilitar interceptor de recursos
        useShouldInterceptRequest: true,
      ),
      onWebViewCreated: (controller) async {
        _webViewController = controller;

        // Agregar JavaScript handlers
        controller.addJavaScriptHandler(
          handlerName: 'PageTracker',
          callback: (args) {
            try {
              final message = args[0] as String;
              final pageData = jsonDecode(message);
              final newPage = pageData['currentPage'] ?? 0;

              print(
                '📄 PageTracker recibido: página $newPage (actual: $_currentPage)',
              );

              if (_currentPage != newPage) {
                print('✅ Actualizando página: $_currentPage → $newPage');

                // Actualizar inmediatamente para que el slider se sincronice
                if (mounted) {
                  setState(() {
                    _currentPage = newPage;
                  });
                }

                // Guardar progreso de forma diferida (sin bloquear UI)
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_currentPage == newPage) {
                    _saveReadingProgress();

                    // Si llegó a la última página, marcar como completado
                    if (newPage >= _images.length - 1) {
                      _markChapterAsCompleted();
                    }
                  }
                });
              }
            } catch (e) {
              print('❌ Error en PageTracker handler: $e');
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

        print('✅ WebView creado y handlers configurados');

        // Si las imágenes ya están cargadas, intentar cargar el HTML
        // (esto maneja el caso en que el WebView se crea tarde)
        if (_images.isNotEmpty) {
          print('🔄 Imágenes ya disponibles, intentando cargar HTML...');
          // Dar un pequeño delay para que _loadReadingProgress pueda ejecutarse primero
          Future.delayed(const Duration(milliseconds: 100), () {
            _loadHtmlContent();
          });
        }
      },
      onLoadStop: (controller, url) async {
        print('🔄 WebView cargado, página actual: $_currentPage');

        // WebView terminó de cargar
        await _injectImageInterceptor();

        // Pequeño delay para asegurar que el DOM esté listo
        await Future.delayed(const Duration(milliseconds: 200));

        // Si hay una página guardada, navegar instantáneamente (showContent se llama automáticamente)
        if (_currentPage > 0) {
          print('🎯 Navegando a página guardada: $_currentPage');
          _navigateToPageInstantly(_currentPage);
        } else {
          // Si no hay progreso guardado (página 0), verificar imágenes críticas y habilitar tracker
          print(
            'ℹ️ Sin progreso guardado, verificando imágenes críticas en página 0',
          );
          final showScript = '''
            (function() {
              // Habilitar tracker inmediatamente ya que no hay scroll
              pageTrackerEnabled = true;
              // Verificar si las imágenes críticas ya están cargadas
              checkCriticalImagesLoaded();
            })();
          ''';
          await controller.evaluateJavascript(source: showScript);
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        // Console logs deshabilitados para mejor performance
        // Descomentar solo para debugging:
        // print('WebView Console: ${consoleMessage.message}');
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();

        // Solo interceptar imágenes de manga
        if (!_images.any(
          (imageUrl) => url.contains(imageUrl) || imageUrl.contains(url),
        )) {
          return null;
        }

        try {
          // Realizar petición directa sin caché para mejor performance
          final response = await _httpClient
              .get(
                Uri.parse(url),
                headers: {
                  'Referer': widget.referer,
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept':
                      'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                },
              )
              .timeout(const Duration(seconds: 10)); // Reducido timeout a 10s

          if (response.statusCode == 200) {
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
