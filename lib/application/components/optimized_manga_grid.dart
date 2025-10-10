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
          childAspectRatio: 0.7,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen optimizada
                Expanded(
                  flex: 3,
                  child: SmartMangaImage(
                    manga: widget.manga,
                    isVisible: _isVisible,
                  ),
                ),
                
                // Información del manga
                Expanded(
                  flex: 2,
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título optimizado
          Flexible(
            child: Text(
              manga.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DraculaTheme.foreground,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          
          // Tags optimizados
          _OptimizedTagRow(manga: manga),
          
          const Spacer(),
          
          // Estado
          Text(
            manga.status,
            style: const TextStyle(
              color: DraculaTheme.comment,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      height: 21, // Altura fija para evitar overflow
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _OptimizedTag(
              text: manga.bookType,
              color: DraculaTheme.purple,
            ),
            if (manga.demography != 'N/A') ...[
              const SizedBox(width: 6),
              _OptimizedTag(
                text: manga.demography,
                color: DraculaTheme.cyan,
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
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
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