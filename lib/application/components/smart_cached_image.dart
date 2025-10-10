import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_avif/flutter_avif.dart' as avif;
import 'package:mangari/core/theme/dracula_theme.dart';

/// Widget inteligente que optimiza la carga de imágenes según su formato
/// Soporta AVIF, WebP, JPEG, PNG y otros formatos con renderizado optimizado
class SmartCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Map<String, String>? httpHeaders;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final String? cacheKey;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Widget? placeholder;
  final Widget? errorWidget;
  final FilterQuality filterQuality;

  const SmartCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.httpHeaders,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.cacheKey,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeOutDuration = const Duration(milliseconds: 150),
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.medium,
  });

  /// Detecta si la URL es una imagen AVIF
  bool get _isAvifImage {
    final url = imageUrl.toLowerCase();
    return url.endsWith('.avif') || 
           url.contains('.avif?') ||
           url.contains('format=avif');
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorFallback();
    }

    // Si es AVIF, usar el renderizador optimizado de AVIF con caché
    if (_isAvifImage) {
      return _buildAvifImage();
    }

    // Para otros formatos, usar CachedNetworkImage con optimizaciones
    return _buildStandardImage();
  }

  /// Construye una imagen AVIF optimizada con caché
  Widget _buildAvifImage() {
    return avif.CachedNetworkAvifImage(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      
      // Headers HTTP - Nota: el parámetro se llama 'headers' no 'httpHeaders'
      headers: httpHeaders,
      
      // Optimizaciones de memoria para AVIF
      // Nota: AVIF usa cacheWidth/cacheHeight en lugar de memCacheWidth/memCacheHeight
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      
      // Calidad de renderizado
      filterQuality: filterQuality,
      
      // Loading builder (equivalente a placeholder)
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildDefaultPlaceholder(showProgress: true);
      },
      
      // Error builder (equivalente a errorWidget)
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildDefaultErrorWidget();
      },
      
      // Gapless playback para transiciones suaves
      gaplessPlayback: true,
    );
  }

  /// Construye una imagen estándar (JPEG, PNG, WebP, etc.) con caché optimizado
  Widget _buildStandardImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      httpHeaders: httpHeaders,
      fit: fit,
      
      // Optimizaciones críticas de memoria
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      
      // Cache key optimizada
      cacheKey: cacheKey,
      
      // Placeholder personalizado o por defecto
      placeholder: (context, url) {
        return placeholder ?? _buildDefaultPlaceholder(showProgress: true);
      },
      
      // Error widget con fallback automático
      errorWidget: (context, url, error) {
        return errorWidget ?? _buildDefaultErrorWidget();
      },
      
      // Image builder optimizado con filterQuality
      imageBuilder: (context, imageProvider) {
        return Image(
          image: imageProvider,
          width: width,
          height: height,
          fit: fit,
          filterQuality: filterQuality,
        );
      },
      
      // Animaciones suaves
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
    );
  }

  /// Placeholder por defecto optimizado
  Widget _buildDefaultPlaceholder({bool showProgress = false}) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      color: DraculaTheme.currentLine,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showProgress ? Icons.downloading : Icons.image,
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

  /// Error widget por defecto
  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width ?? double.infinity,
      height: height,
      color: DraculaTheme.currentLine,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: DraculaTheme.red,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Error al cargar',
            style: TextStyle(
              color: DraculaTheme.red,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback cuando no hay URL
  Widget _buildErrorFallback() {
    return Container(
      width: width ?? double.infinity,
      height: height,
      color: DraculaTheme.currentLine,
      child: const Icon(
        Icons.image_not_supported,
        color: DraculaTheme.comment,
        size: 48,
      ),
    );
  }
}

/// Extensión de SmartCachedImage específica para tarjetas de manga
class MangaCoverImage extends StatelessWidget {
  final String imageUrl;
  final String referer;
  final String mangaId;
  final bool isVisible;

  const MangaCoverImage({
    super.key,
    required this.imageUrl,
    required this.referer,
    required this.mangaId,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    // No cargar si no es visible (optimización de rendimiento)
    if (!isVisible && imageUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        color: DraculaTheme.currentLine,
        child: const Icon(
          Icons.image,
          color: DraculaTheme.comment,
          size: 48,
        ),
      );
    }

    return SmartCachedImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      httpHeaders: {
        'Referer': referer,
        'User-Agent': 'Mozilla/5.0 (compatible; MangaReader/1.0)',
      },
      
      // Optimizaciones específicas para covers de manga
      memCacheWidth: 300,
      memCacheHeight: 450,
      maxWidthDiskCache: 400,
      maxHeightDiskCache: 600,
      
      // Cache key única basada en el manga ID y URL
      cacheKey: _generateCacheKey(),
      
      // Calidad de renderizado optimizada para portadas
      filterQuality: FilterQuality.medium,
      
      // Animaciones rápidas para mejor UX
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 100),
      
      // Placeholder optimizado con indicador de carga
      placeholder: _buildPlaceholder(showProgress: true),
      
      // Error widget personalizado
      errorWidget: _buildErrorWidget(),
    );
  }

  /// Genera una cache key única y optimizada
  String _generateCacheKey() {
    // Limpiar la URL de parámetros dinámicos para mejor caché
    final cleanUrl = imageUrl.split('?').first;
    return 'manga_cover_${mangaId}_${cleanUrl.hashCode}';
  }

  /// Placeholder optimizado que muestra progreso de carga
  Widget _buildPlaceholder({bool showProgress = false}) {
    return Container(
      width: double.infinity,
      color: DraculaTheme.currentLine,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showProgress ? Icons.downloading : Icons.image,
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

  /// Error widget optimizado
  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      color: DraculaTheme.currentLine,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: DraculaTheme.red,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Error al cargar',
            style: TextStyle(
              color: DraculaTheme.red,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
