import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/chapter_entity.dart';
import 'package:mangari/domain/entities/genre_entity.dart';
import 'package:mangari/domain/entities/editorial_entity.dart';
import 'package:mangari/domain/entities/chapter_view_entity.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/application/views/manga_reader_view.dart';

class MangaDetailView extends StatefulWidget {
  final MangaDetailEntity manga;
  final ServerEntity server;

  const MangaDetailView({
    super.key,
    required this.manga,
    required this.server,
  });

  @override
  State<MangaDetailView> createState() => _MangaDetailViewState();
}

class _MangaDetailViewState extends State<MangaDetailView> {
  ServersServiceV2? _serversService;
  
  MangaDetailEntity? _mangaDetail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDescriptionExpanded = false;
  ChapterViewEntity? _selectedChapter;
  bool _showImageZoom = false;

  @override
  void initState() {
    super.initState();
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  void _initializeService() async {
    try {
      print('🔍 MangaDetailView: Intentando obtener ServersServiceV2...');
      await Future.delayed(const Duration(milliseconds: 50));
      
      _serversService = getServersServiceSafely();
      
      if (_serversService != null) {
        print('✅ MangaDetailView: ServersServiceV2 obtenido correctamente');
        await _loadMangaDetails();
      } else {
        print('❌ MangaDetailView: No se pudo obtener ServersServiceV2');
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo inicializar el servicio de servidores';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ MangaDetailView: Error en _initializeService: $e');
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
      if (serverId == 'mangadex') {
        serverId = 'mangadex';
      } else if (serverId == 'tmo') {
        serverId = 'tmo';
      }

        final detailedManga = await _serversService!.getMangaDetailFromServer(serverId, widget.manga.id);
        // Convertir de vuelta a MangaDetailEntity
        final detailedMangaEntity = MangaDetailEntity(
          title: detailedManga.title,
          linkImage: (detailedManga.coverImageUrl?.isEmpty ?? true) ? widget.manga.linkImage : detailedManga.coverImageUrl!,
        link: widget.manga.link,
        bookType: widget.manga.bookType,
        demography: widget.manga.demography,
        id: detailedManga.id,
        service: serverId,
        description: detailedManga.description ?? widget.manga.description,
        genres: detailedManga.genres.map((genreText) => GenreEntity(text: genreText, href: '')).toList(),
        chapters: detailedManga.chapters,
        author: detailedManga.authors.isNotEmpty ? detailedManga.authors.first : widget.manga.author,
        status: detailedManga.status,
        source: detailedManga.serverSource,
        referer: detailedManga.referer ?? widget.manga.referer,
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
        referer: manga.referer ?? '',
        onBack: () {
          setState(() {
            _selectedChapter = null;
          });
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
        children: [
          _buildBody(),
          if (_showImageZoom) _buildImageZoomOverlay(),
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
              'Cargando detalles...',
              style: TextStyle(
                color: DraculaTheme.foreground,
                fontSize: 16,
              ),
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
            if (manga.genres.isNotEmpty) _buildGenresSection(manga.genres),
            if (manga.description.isNotEmpty) _buildDescriptionSection(manga.description),
            _buildChaptersSection(manga.chapters),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(MangaDetailEntity manga) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: DraculaTheme.currentLine,
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
                borderRadius: BorderRadius.circular(8),
                color: DraculaTheme.selection,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: manga.linkImage.trim(),
                      httpHeaders: {
                        'Referer': manga.referer ?? '',
                      },
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 240,
                      memCacheHeight: 360,
                      placeholder: (context, url) => Container(
                        color: DraculaTheme.selection,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: DraculaTheme.purple,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
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
                    // Overlay sutil para indicar que es clickeable
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
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
                Text(
                  manga.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DraculaTheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                
                if (manga.author.isNotEmpty && manga.author != 'Autor desconocido')
                  _buildInfoRow(Icons.person, manga.author),
                
                if (manga.status.isNotEmpty && manga.status != 'Estado desconocido')
                  _buildInfoRow(Icons.info_outline, manga.status),
                
                const SizedBox(height: 12),
                
                // Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(manga.bookType, DraculaTheme.purple),
                    if (manga.demography.isNotEmpty && manga.demography != 'N/A')
                      _buildBadge(manga.demography, DraculaTheme.cyan),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          const Text(
            'Géneros',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: DraculaTheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres.map((genre) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DraculaTheme.currentLine,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                genre.text,
                style: const TextStyle(
                  color: DraculaTheme.foreground,
                  fontSize: 12,
                ),
              ),
            )).toList(),
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
                  style: TextStyle(
                    color: DraculaTheme.comment,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return _buildChapterItem(chapter);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChapterItem(ChapterEntity chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DraculaTheme.currentLine,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapter.numAndTitleCap,
                  style: const TextStyle(
                    color: DraculaTheme.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: DraculaTheme.comment,
              ),
            ],
          ),
          
          if (chapter.editorials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: chapter.editorials.map((editorial) => 
                _buildEditorialButton(chapter, editorial)
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorialButton(ChapterEntity chapter, EditorialEntity editorial) {
    return InkWell(
      onTap: () => _onChapterTap(chapter, editorial),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: DraculaTheme.purple,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editorial.editorialName,
              style: const TextStyle(
                color: DraculaTheme.background,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new,
              size: 14,
              color: DraculaTheme.background,
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
                    child: CachedNetworkImage(
                      imageUrl: manga.linkImage,
                      httpHeaders: {
                        'Referer': manga.referer ?? '',
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                      },
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
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
                      errorWidget: (context, url, error) => Container(
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
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