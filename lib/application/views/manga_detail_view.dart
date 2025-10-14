import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/chapter_entity.dart';
import 'package:mangari/domain/entities/genre_entity.dart';
import 'package:mangari/domain/entities/editorial_entity.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/application/services/library_service.dart';
import 'package:mangari/infrastructure/database/database_service.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/application/views/manga_reader_view.dart';
import 'package:mangari/application/components/smart_cached_image.dart';

class MangaDetailView extends StatefulWidget {
  final MangaDetailEntity manga;
  final ServerEntity server;

  const MangaDetailView({super.key, required this.manga, required this.server});

  @override
  State<MangaDetailView> createState() => _MangaDetailViewState();
}

class _MangaDetailViewState extends State<MangaDetailView> with RouteAware {
  ServersServiceV2? _serversService;
  LibraryService? _libraryService;
  DatabaseService? _databaseService;

  MangaDetailEntity? _mangaDetail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDescriptionExpanded = false;
  ChapterViewEntity? _selectedChapter;
  bool _showImageZoom = false;
  bool _isSaved = false;

  // Cache para el progreso de lectura de cada capítulo
  Map<String, Map<String, dynamic>> _chapterProgressCache = {};

  @override
  void initState() {
    super.initState();
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-verificar si el manga está guardado cuando volvemos a esta pantalla
    if (_libraryService != null) {
      _checkIfMangaIsSaved();
    }
  }

  void _initializeService() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));

      _serversService = getServersServiceSafely();
      _libraryService = getLibraryServiceSafely();
      _databaseService = DatabaseService();

      if (_serversService != null) {
        await _loadMangaDetails();

        if (_libraryService != null) {
          await _checkIfMangaIsSaved();
        }

        // Cargar el progreso de lectura de todos los capítulos
        await _loadChaptersProgress();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo inicializar el servicio de servidores';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error inicializando servicios: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inicializando servicios: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMangaDetails() async {
    if (_serversService == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Determinar el servidor basado en el service del manga
      String serverId = widget.manga.service.toLowerCase();

      final detailedManga = await _serversService!.getMangaDetailFromServer(
        serverId,
        widget.manga.id,
      );
      // Convertir de vuelta a MangaDetailEntity
      final detailedMangaEntity = MangaDetailEntity(
        title: detailedManga.title,
        linkImage:
            (detailedManga.coverImageUrl?.isEmpty ?? true)
                ? widget.manga.linkImage
                : detailedManga.coverImageUrl!,
        link: widget.manga.link,
        bookType: widget.manga.bookType,
        demography: widget.manga.demography,
        id: detailedManga.id,
        service: serverId,
        description: detailedManga.description ?? widget.manga.description,
        genres:
            detailedManga.genres
                .map((genreText) => GenreEntity(text: genreText, href: ''))
                .toList(),
        chapters: detailedManga.chapters,
        author:
            detailedManga.authors.isNotEmpty
                ? detailedManga.authors.first
                : widget.manga.author,
        status: detailedManga.status,
        source: detailedManga.serverSource,
        referer: detailedManga.referer,
      );

      setState(() {
        _mangaDetail = detailedMangaEntity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _mangaDetail = widget.manga; // Usar datos básicos como fallback
      });
    }
  }

  Future<void> _checkIfMangaIsSaved() async {
    if (_libraryService == null) return;

    try {
      // Limpiar y normalizar IDs (trim + lowercase para serverId)
      final cleanMangaId = widget.manga.id.trim();
      final cleanServiceId = widget.manga.service.trim().toLowerCase();

      final isSaved = await _libraryService!.isMangaSaved(
        cleanMangaId,
        cleanServiceId,
      );

      if (mounted) {
        setState(() => _isSaved = isSaved);
      }
    } catch (e) {
      print('❌ Error verificando si el manga está guardado: $e');
    }
  }

  /// Carga el progreso de lectura de todos los capítulos
  Future<void> _loadChaptersProgress() async {
    if (_databaseService == null) return;

    final manga = _mangaDetail ?? widget.manga;
    if (manga.chapters.isEmpty) return;

    try {
      final cleanMangaId = manga.id.trim();
      final cleanServiceId = manga.service.trim().toLowerCase();

      // Obtener el progreso de todos los capítulos de este manga
      final progressList = await _databaseService!.getReadingProgressByManga(
        mangaId: cleanMangaId,
        serverId: cleanServiceId,
      );

      // Convertir a un mapa para acceso rápido
      final progressMap = <String, Map<String, dynamic>>{};
      for (var progress in progressList) {
        final key = '${progress['chapter_id']}_${progress['editorial']}';
        progressMap[key] = progress;
      }

      if (mounted) {
        setState(() {
          _chapterProgressCache = progressMap;
        });
      }
    } catch (e) {
      print('❌ Error cargando progreso de capítulos: $e');
    }
  }

  /// Obtiene el progreso de un capítulo específico
  Map<String, dynamic>? _getChapterProgress(
    String editorialLink,
    String editorialName,
  ) {
    final key = '${editorialLink}_$editorialName';
    return _chapterProgressCache[key];
  }

  Future<void> _saveManga({String? category}) async {
    if (_libraryService == null) return;

    final manga = _mangaDetail ?? widget.manga;
    final selectedCategory = category ?? 'Predeterminado';

    try {
      final success = await _libraryService!.saveManga(
        manga: manga,
        serverName: widget.server.name,
        category: selectedCategory,
      );

      if (success && mounted) {
        setState(() => _isSaved = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado en "$selectedCategory"'),
            backgroundColor: DraculaTheme.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Re-verificar el estado después de guardar
        await _checkIfMangaIsSaved();
      }
    } catch (e) {
      print('❌ Error guardando manga: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: DraculaTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteManga() async {
    if (_libraryService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: DraculaTheme.background,
            title: const Text(
              'Eliminar manga',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
            content: const Text(
              '¿Estás seguro de que quieres eliminar este manga de tu biblioteca? Esta acción no se puede deshacer.',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: DraculaTheme.comment),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.red,
                  foregroundColor: DraculaTheme.background,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteManga();
    }
  }

  Future<void> _deleteManga() async {
    if (_libraryService == null) return;

    final manga = _mangaDetail ?? widget.manga;

    try {
      final success = await _libraryService!.deleteSavedManga(
        manga.id.trim(),
        manga.service.trim().toLowerCase(),
      );

      if (success && mounted) {
        setState(() => _isSaved = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manga eliminado de la biblioteca'),
            backgroundColor: DraculaTheme.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        // Re-verificar el estado
        await _checkIfMangaIsSaved();
      }
    } catch (e) {
      print('❌ Error eliminando manga: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: DraculaTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showSaveCategoryDialog() async {
    if (_libraryService == null) return;

    final categories = await _libraryService!.getCategories();

    if (!mounted) return;

    final selectedCategory = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: DraculaTheme.background,
            title: const Text(
              'Seleccionar categoría',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(
                      category,
                      style: const TextStyle(color: DraculaTheme.foreground),
                    ),
                    trailing:
                        category == 'Predeterminado'
                            ? const Icon(Icons.star, color: DraculaTheme.yellow)
                            : null,
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: DraculaTheme.comment),
                ),
              ),
            ],
          ),
    );

    if (selectedCategory != null) {
      await _saveManga(category: selectedCategory);
    }
  }

  void _onChapterTap(ChapterEntity chapter, EditorialEntity editorial) {
    final chapterView = ChapterViewEntity(
      editorialName: editorial.editorialName,
      editorialLink: editorial.editorialLink,
      chapterTitle: chapter.numAndTitleCap,
    );

    setState(() {
      _selectedChapter = chapterView;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si hay un capítulo seleccionado, mostrar el lector
    if (_selectedChapter != null) {
      final manga = _mangaDetail ?? widget.manga;
      return MangaReaderView(
        chapter: _selectedChapter!,
        server: widget.server,
        mangaTitle: manga.title,
        mangaId: manga.id,
        referer: manga.referer ?? '',
        onBack: () {
          setState(() {
            _selectedChapter = null;
          });
          // Recargar el progreso de los capítulos
          _loadChaptersProgress();
        },
      );
    }

    return Scaffold(
      backgroundColor: DraculaTheme.background,
      appBar: AppBar(
        backgroundColor: DraculaTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DraculaTheme.purple),
          onPressed: () {
            if (_showImageZoom) {
              setState(() {
                _showImageZoom = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _mangaDetail?.title ?? widget.manga.title,
          style: const TextStyle(
            color: DraculaTheme.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [_buildBody(), if (_showImageZoom) _buildImageZoomOverlay()],
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
              'Cargando detalles...',
              style: TextStyle(color: DraculaTheme.foreground, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _mangaDetail == null) {
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
              Text(
                'Error al cargar detalles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: DraculaTheme.foreground,
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
                onPressed: _loadMangaDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.purple,
                  foregroundColor: DraculaTheme.background,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final manga = _mangaDetail ?? widget.manga;

    return RefreshIndicator(
      onRefresh: _loadMangaDetails,
      color: DraculaTheme.purple,
      backgroundColor: DraculaTheme.currentLine,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(manga),
            _buildActionButtons(),
            if (manga.genres.isNotEmpty) _buildGenresSection(manga.genres),
            if (manga.description.isNotEmpty)
              _buildDescriptionSection(manga.description),
            _buildChaptersSection(manga.chapters),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(MangaDetailEntity manga) {
    return Container(
      height: 280,
      child: Stack(
        children: [
          // Imagen de fondo difuminada
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: SmartCachedImage(
                  imageUrl: manga.linkImage.trim(),
                  httpHeaders: {
                    'Referer': manga.referer ?? '',
                    'User-Agent': 'Mozilla/5.0 (compatible; MangaReader/1.0)',
                  },
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 800,
                  memCacheHeight: 600,
                  cacheKey: 'manga_detail_bg_${manga.id}',
                  filterQuality: FilterQuality.high,
                  placeholder: Container(
                    color: DraculaTheme.currentLine,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: DraculaTheme.purple,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: DraculaTheme.currentLine,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: DraculaTheme.comment,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Overlay con gradiente Dracula
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DraculaTheme.background.withOpacity(0.2),
                    DraculaTheme.background.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // Card con estilo Dracula mejorado
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: DraculaTheme.purple.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: DraculaTheme.currentLine.withOpacity(0.7),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Imagen de portada
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showImageZoom = true;
                            });
                          },
                          child: Container(
                            width: 120,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: DraculaTheme.selection,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  SmartCachedImage(
                                    imageUrl: manga.linkImage.trim(),
                                    httpHeaders: {
                                      'Referer': manga.referer ?? '',
                                      'User-Agent':
                                          'Mozilla/5.0 (compatible; MangaReader/1.0)',
                                    },
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    memCacheWidth: 240,
                                    memCacheHeight: 360,
                                    cacheKey: 'manga_detail_cover_${manga.id}',
                                    filterQuality: FilterQuality.high,
                                    placeholder: Container(
                                      color: DraculaTheme.selection,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: DraculaTheme.purple,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: Container(
                                      color: DraculaTheme.selection,
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: DraculaTheme.comment,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Overlay para indicar que es clickeable
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Detalles del manga
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onLongPress: _copyTitle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    manga.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              if (manga.author.isNotEmpty &&
                                  manga.author != 'Autor desconocido')
                                _buildInfoRowHero(Icons.person, manga.author),

                              if (manga.status.isNotEmpty &&
                                  manga.status != 'Estado desconocido')
                                _buildInfoRowHero(
                                  Icons.info_outline,
                                  manga.status,
                                ),

                              const SizedBox(height: 12),

                              // Badges
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildBadgeHero(
                                    manga.bookType,
                                    DraculaTheme.purple,
                                  ),
                                  if (manga.demography.isNotEmpty &&
                                      manga.demography != 'N/A')
                                    _buildBadgeHero(
                                      manga.demography,
                                      DraculaTheme.cyan,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Botón de Guardar/Cambiar categoría
          Expanded(
            flex: _isSaved ? 2 : 3,
            child: GestureDetector(
              onLongPress: _showSaveCategoryDialog,
              child: ElevatedButton.icon(
                onPressed:
                    _isSaved ? _showSaveCategoryDialog : () => _saveManga(),
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(
                  _isSaved ? 'Cambiar categoría' : 'Guardar',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSaved ? DraculaTheme.green : DraculaTheme.purple,
                  foregroundColor: DraculaTheme.background,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          if (_isSaved) const SizedBox(width: 8),

          // Botón de Eliminar (solo si está guardado)
          if (_isSaved)
            IconButton(
              onPressed: _confirmDeleteManga,
              icon: const Icon(Icons.delete_outline),
              color: DraculaTheme.red,
              tooltip: 'Eliminar de biblioteca',
              style: IconButton.styleFrom(
                backgroundColor: DraculaTheme.red.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

          if (_isSaved) const SizedBox(width: 8),

          // Botón de Descargar (solo si está guardado)
          if (_isSaved)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _showDownloadOptions,
                icon: const Icon(Icons.download),
                label: const Text('Descargar', overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.cyan,
                  foregroundColor: DraculaTheme.background,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDownloadOptions() async {
    final manga = _mangaDetail ?? widget.manga;

    if (manga.chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay capítulos disponibles para descargar'),
          backgroundColor: DraculaTheme.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Obtener todas las editoriales disponibles
    final Set<String> editorials = {};
    for (final chapter in manga.chapters) {
      for (final editorial in chapter.editorials) {
        editorials.add(editorial.editorialName);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: DraculaTheme.background,
            title: const Text(
              'Descargar capítulos',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona la editorial:',
                  style: TextStyle(color: DraculaTheme.comment),
                ),
                const SizedBox(height: 12),
                ...editorials.map(
                  (editorial) => ListTile(
                    title: Text(
                      editorial,
                      style: const TextStyle(color: DraculaTheme.foreground),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: DraculaTheme.purple,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _startDownload(editorial);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: DraculaTheme.comment),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _startDownload(String editorial) async {
    if (_libraryService == null) return;

    final manga = _mangaDetail ?? widget.manga;

    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: DraculaTheme.background,
            title: const Text(
              'Descargando capítulos',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: DraculaTheme.purple),
                const SizedBox(height: 16),
                const Text(
                  'Descargando...',
                  style: TextStyle(color: DraculaTheme.foreground),
                ),
              ],
            ),
          ),
    );

    try {
      final downloaded = await _libraryService!.downloadMultipleChapters(
        mangaId: manga.id,
        mangaTitle: manga.title,
        serverId: manga.service,
        serverName: widget.server.name,
        chapters: manga.chapters,
        editorial: editorial,
        onChapterProgress: (current, total, chapterName) {
          print('📥 Descargando $current/$total: $chapterName');
        },
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Descargados ${downloaded.length} capítulos'),
            backgroundColor: DraculaTheme.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error descargando capítulos: $e');
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: DraculaTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Copia el título del manga al portapapeles
  Future<void> _copyTitle() async {
    final manga = _mangaDetail ?? widget.manga;

    try {
      await Clipboard.setData(ClipboardData(text: manga.title));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Título copiado al portapapeles'),
            backgroundColor: DraculaTheme.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error copiando título: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar título: $e'),
            backgroundColor: DraculaTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Copia un género específico al portapapeles
  Future<void> _copyGenre(String genreText) async {
    try {
      await Clipboard.setData(ClipboardData(text: genreText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Género "$genreText" copiado'),
            backgroundColor: DraculaTheme.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error copiando género: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar género: $e'),
            backgroundColor: DraculaTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DraculaTheme.comment),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: DraculaTheme.foreground,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowHero(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: DraculaTheme.background,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBadgeHero(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGenresSection(List<GenreEntity> genres) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DraculaTheme.currentLine, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Géneros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: DraculaTheme.foreground,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DraculaTheme.comment.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Mantén presionado para copiar',
                  style: TextStyle(
                    color: DraculaTheme.comment,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                genres
                    .map(
                      (genre) => GestureDetector(
                        onLongPress: () => _copyGenre(genre.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: DraculaTheme.currentLine,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: DraculaTheme.purple.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                genre.text,
                                style: const TextStyle(
                                  color: DraculaTheme.foreground,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy,
                                size: 10,
                                color: DraculaTheme.comment,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DraculaTheme.currentLine, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sinopsis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: DraculaTheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: DraculaTheme.foreground,
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
          ),
          if (description.length > 150)
            TextButton(
              onPressed: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isDescriptionExpanded ? 'Mostrar menos' : 'Mostrar más',
                style: const TextStyle(
                  color: DraculaTheme.purple,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChaptersSection(List<ChapterEntity> chapters) {
    // Expandir todos los capítulos con sus editoriales
    final List<Map<String, dynamic>> expandedChapters = [];

    for (final chapter in chapters) {
      for (final editorial in chapter.editorials) {
        expandedChapters.add({'chapter': chapter, 'editorial': editorial});
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capítulos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: DraculaTheme.foreground,
            ),
          ),
          const SizedBox(height: 12),

          if (chapters.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay capítulos disponibles',
                  style: TextStyle(color: DraculaTheme.comment, fontSize: 16),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expandedChapters.length,
              itemBuilder: (context, index) {
                final data = expandedChapters[index];
                final chapter = data['chapter'] as ChapterEntity;
                final editorial = data['editorial'] as EditorialEntity;
                return _buildChapterItemWithEditorial(chapter, editorial);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChapterItemWithEditorial(
    ChapterEntity chapter,
    EditorialEntity editorial,
  ) {
    // Obtener el progreso de este capítulo
    final progress = _getChapterProgress(
      editorial.editorialLink,
      editorial.editorialName,
    );
    final isCompleted = progress != null && progress['is_completed'] == 1;
    final currentPage = progress?['current_page'] ?? 0;
    final totalPages = progress?['total_pages'] ?? 0;
    final hasProgress = progress != null && currentPage > 0;

    return InkWell(
      onTap: () => _onChapterTap(chapter, editorial),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DraculaTheme.currentLine,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isCompleted
                    ? DraculaTheme.green.withOpacity(0.5)
                    : DraculaTheme.selection.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Indicador de leído/en progreso
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: Icon(
                isCompleted
                    ? Icons.check_circle
                    : hasProgress
                    ? Icons.play_circle_outline
                    : Icons.circle_outlined,
                color:
                    isCompleted
                        ? DraculaTheme.green
                        : hasProgress
                        ? DraculaTheme.orange
                        : DraculaTheme.comment,
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título del capítulo
                  Text(
                    chapter.numAndTitleCap,
                    style: TextStyle(
                      color:
                          isCompleted
                              ? DraculaTheme.comment
                              : DraculaTheme.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Editorial
                  Row(
                    children: [
                      const Icon(
                        Icons.language,
                        size: 12,
                        color: DraculaTheme.purple,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          editorial.editorialName,
                          style: const TextStyle(
                            color: DraculaTheme.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasProgress && !isCompleted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: DraculaTheme.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pág. ${currentPage + 1}/$totalPages',
                  style: const TextStyle(
                    color: DraculaTheme.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: DraculaTheme.comment,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageZoomOverlay() {
    final manga = _mangaDetail ?? widget.manga;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showImageZoom = false;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              // Imagen con zoom
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: SmartCachedImage(
                      imageUrl: manga.linkImage,
                      httpHeaders: {
                        'Referer': manga.referer ?? '',
                        'User-Agent':
                            'Mozilla/5.0 (compatible; MangaReader/1.0)',
                      },
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.8,
                      memCacheWidth: 800,
                      memCacheHeight: 1200,
                      cacheKey: 'manga_detail_zoom_${manga.id}',
                      filterQuality: FilterQuality.high,
                      placeholder: Container(
                        width: 200,
                        height: 300,
                        color: DraculaTheme.selection,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: DraculaTheme.purple,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      errorWidget: Container(
                        width: 200,
                        height: 300,
                        color: DraculaTheme.selection,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: DraculaTheme.red,
                                size: 64,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Error al cargar imagen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Botón de cerrar
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showImageZoom = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Indicador de ayuda
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pellizca para hacer zoom • Toca para cerrar',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
