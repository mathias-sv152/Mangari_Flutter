import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/application/components/performance_utils.dart';
import 'package:mangari/application/components/smart_cached_image.dart';

/// Grid optimizado para mostrar mangas con alto rendimiento
class OptimizedMangaGrid extends StatefulWidget {
  final List<MangaDetailEntity> mangas;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final Function(MangaDetailEntity) onMangaTap;
  final VoidCallback onRefresh;

  const OptimizedMangaGrid({
    super.key,
    required this.mangas,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onMangaTap,
    required this.onRefresh,
  });

  @override
  State<OptimizedMangaGrid> createState() => _OptimizedMangaGridState();
}

class _OptimizedMangaGridState extends State<OptimizedMangaGrid>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _visibleItems = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Configurar caché de imágenes
    MangaImageCacheManager.configureCacheSettings();
    
    // Agregar listener para métricas de scroll
    widget.scrollController.addListener(_onScrollUpdate);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollUpdate);
    super.dispose();
  }

  void _onScrollUpdate() {
    PerformanceMetrics.recordScrollEvent();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: DraculaTheme.purple,
      backgroundColor: DraculaTheme.currentLine,
      child: GridView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        // Optimizaciones críticas de rendimiento
        cacheExtent: 2000, // Precarga más elementos fuera de pantalla
        addAutomaticKeepAlives: true, // Mantener widgets vivos
        addRepaintBoundaries: true, // Optimizar repintado
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // Más alto para dar espacio al texto
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: widget.mangas.length + (widget.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.mangas.length) {
            return const _LoadingCard();
          }

          final manga = widget.mangas[index];
          return OptimizedMangaCard(
            key: ValueKey('manga_${manga.id}_$index'),
            manga: manga,
            onTap: () => widget.onMangaTap(manga),
            onVisibilityChanged: (isVisible) {
              if (isVisible) {
                _visibleItems.add(manga.id);
              } else {
                _visibleItems.remove(manga.id);
              }
            },
          );
        },
      ),
    );
  }
}

/// Tarjeta de manga optimizada con gestión inteligente de visibilidad
class OptimizedMangaCard extends StatefulWidget {
  final MangaDetailEntity manga;
  final VoidCallback onTap;
  final Function(bool) onVisibilityChanged;

  const OptimizedMangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    required this.onVisibilityChanged,
  });

  @override
  State<OptimizedMangaCard> createState() => _OptimizedMangaCardState();
}

class _OptimizedMangaCardState extends State<OptimizedMangaCard>
    with AutomaticKeepAliveClientMixin {
  bool _isVisible = false;

  @override
  bool get wantKeepAlive => _isVisible;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return VisibilityDetector(
      key: Key('manga_visibility_${widget.manga.id}'),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        
        // Usar utilidades de rendimiento para decidir si mantener en memoria
        _isVisible = PerformanceOptimizer.shouldKeepInMemory(
          info.visibleFraction, 
          wasVisible,
        );
        
        if (wasVisible != _isVisible) {
          widget.onVisibilityChanged(_isVisible);
          if (mounted) {
            setState(() {});
          }
        }
      },
      child: RepaintBoundary(
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imagen optimizada con altura flexible
                Expanded(
                  child: SmartMangaImage(
                    manga: widget.manga,
                    isVisible: _isVisible,
                  ),
                ),
                
                // Información del manga con altura fija
                SizedBox(
                  height: 110, // Altura fija para garantizar espacio al texto
                  child: MangaInfoPanel(manga: widget.manga),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget inteligente para cargar imágenes solo cuando son visibles
/// Ahora soporta AVIF y todos los formatos con optimización automática
class SmartMangaImage extends StatelessWidget {
  final MangaDetailEntity manga;
  final bool isVisible;

  const SmartMangaImage({
    super.key,
    required this.manga,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (manga.linkImage.isEmpty) {
      return _buildPlaceholder(Icons.image_not_supported);
    }

    // Solo cargar imagen si está visible o cerca de ser visible
    if (!isVisible) {
      return _buildPlaceholder(Icons.image);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: DraculaTheme.currentLine,
      child: MangaCoverImage(
        imageUrl: manga.linkImage,
        referer: manga.referer ?? '',
        mangaId: manga.id,
        isVisible: isVisible,
      ),
    );
  }

  Widget _buildPlaceholder(IconData icon, {bool showProgress = false}) {
    return Container(
      width: double.infinity,
      color: DraculaTheme.currentLine,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: DraculaTheme.comment,
            size: 48,
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: DraculaTheme.purple,
                strokeWidth: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel de información optimizado del manga
class MangaInfoPanel extends StatelessWidget {
  final MangaDetailEntity manga;

  const MangaInfoPanel({
    super.key,
    required this.manga,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: DraculaTheme.currentLine.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: DraculaTheme.comment.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título optimizado con altura fija
          SizedBox(
            height: 36, // Reducido para evitar overflow
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                manga.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DraculaTheme.foreground,
                  height: 1.3,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 5),
          
          // Tags optimizados
          _OptimizedTagRow(manga: manga),
          const SizedBox(height: 5),
          
          // Estado con fondo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: DraculaTheme.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              manga.status,
              style: const TextStyle(
                color: DraculaTheme.purple,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row de tags optimizado que evita reconstrucciones innecesarias
class _OptimizedTagRow extends StatelessWidget {
  final MangaDetailEntity manga;

  const _OptimizedTagRow({required this.manga});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22, // Altura fija para evitar overflow
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _OptimizedTag(
              text: manga.bookType,
              color: DraculaTheme.cyan,
            ),
            if (manga.demography != 'N/A') ...[
              const SizedBox(width: 5),
              _OptimizedTag(
                text: manga.demography,
                color: DraculaTheme.green,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tag optimizado que minimiza reconstrucciones
class _OptimizedTag extends StatelessWidget {
  final String text;
  final Color color;

  const _OptimizedTag({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          textBaseline: TextBaseline.alphabetic,
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Card de carga optimizada
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: DraculaTheme.currentLine.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: DraculaTheme.purple,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Cargando...',
                style: TextStyle(
                  color: DraculaTheme.comment,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}