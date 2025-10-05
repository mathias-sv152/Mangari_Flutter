import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Utilidades para optimización de rendimiento en listas de manga
class PerformanceOptimizer {
  static const String _tag = 'MangaPerformance';
  
  /// Solo registra métricas en modo debug y si son relevantes
  static void logPerformance(String operation, int duration) {
    if (kDebugMode && duration > 100) {
      developer.log(
        '⚠️  Operación lenta: $operation (${duration}ms)',
        name: _tag,
        level: 900, // Warning level
      );
    }
  }
  
  /// Log optimizado para desarrollo
  static void logInfo(String message) {
    if (kDebugMode) {
      developer.log(
        '💡 $message',
        name: _tag,
        level: 800, // Info level
      );
    }
  }
  
  /// Optimiza el scroll basado en la velocidad
  static double optimizeScrollSpeed(double velocity) {
    // Reducir la frecuencia de actualizaciones durante scroll rápido
    if (velocity.abs() > 1000) {
      return 0.5; // 50% de actualizaciones durante scroll rápido
    } else if (velocity.abs() > 500) {
      return 0.7; // 70% de actualizaciones durante scroll medio
    }
    return 1.0; // 100% de actualizaciones durante scroll lento
  }
  
  /// Calcula el número óptimo de elementos a precargar
  static int calculateOptimalCacheExtent(int itemCount, double viewportHeight) {
    // Calcular basado en el tamaño del viewport y número de elementos
    final baseCache = (viewportHeight * 2).round();
    return baseCache.clamp(500, 3000);
  }
  
  /// Determina si un elemento debe mantenerse en memoria
  static bool shouldKeepInMemory(double visibilityFraction, bool wasVisible) {
    // Mantener en memoria si está visible o estuvo visible recientemente
    return visibilityFraction > 0.1 || (wasVisible && visibilityFraction > 0.01);
  }
  
  /// Optimiza el tamaño de las imágenes basado en el dispositivo
  static Map<String, int> getOptimalImageSize() {
    // Ajustar basado en la densidad de píxeles del dispositivo
    // TODO: Implementar detección de dispositivo
    return {
      'memCacheWidth': 300,
      'memCacheHeight': 450,
      'diskCacheWidth': 400,
      'diskCacheHeight': 600,
    };
  }
}

/// Manager para el caché de imágenes de manga
class MangaImageCacheManager {
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int _maxCacheObjects = 200; // 200 imágenes máximo
  
  /// Configura el caché para optimizar memoria
  static void configureCacheSettings() {
    if (kDebugMode) {
      PerformanceOptimizer.logInfo(
        'Cache configurado: ${_maxCacheSize ~/ (1024 * 1024)}MB, ${_maxCacheObjects} objetos'
      );
    }
  }
  
  /// Limpia el caché cuando sea necesario
  static Future<void> clearCacheIfNeeded() async {
    try {
      // TODO: Implementar limpieza inteligente del caché
      if (kDebugMode) {
        PerformanceOptimizer.logInfo('Cache limpiado por gestión de memoria');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('❌ Error limpiando cache: $e', name: 'MangaCache', level: 1000);
      }
    }
  }
  
  /// Genera key optimizada para cache
  static String generateCacheKey(String mangaId, String imageUrl) {
    return 'manga_${mangaId}_${imageUrl.hashCode}';
  }
}

/// Métricas de rendimiento para monitoreo
class PerformanceMetrics {
  static int _imageLoadCount = 0;
  static int _imageLoadErrors = 0;
  static int _scrollEvents = 0;
  static DateTime _lastReport = DateTime.now();
  
  static void recordImageLoad() {
    _imageLoadCount++;
    _checkAndReport();
  }
  
  static void recordImageError() {
    _imageLoadErrors++;
    _checkAndReport();
  }
  
  static void recordScrollEvent() {
    _scrollEvents++;
  }
  
  static void _checkAndReport() {
    final now = DateTime.now();
    if (now.difference(_lastReport).inMinutes >= 1) {
      _reportMetrics();
      _resetMetrics();
    }
  }
  
  static void _reportMetrics() {
    if (!kDebugMode) return;
    
    final errorRate = _imageLoadCount > 0 
        ? (_imageLoadErrors / _imageLoadCount * 100).toStringAsFixed(1)
        : '0.0';
    
    PerformanceOptimizer.logInfo(
      'Métricas (1min): ${_imageLoadCount} imágenes, ${_imageLoadErrors} errores (${errorRate}%), ${_scrollEvents} scrolls'
    );
  }
  
  static void _resetMetrics() {
    _imageLoadCount = 0;
    _imageLoadErrors = 0;
    _scrollEvents = 0;
    _lastReport = DateTime.now();
  }
  
  /// Obtiene estadísticas actuales
  static Map<String, dynamic> getCurrentStats() {
    return {
      'imageLoadCount': _imageLoadCount,
      'imageLoadErrors': _imageLoadErrors,
      'scrollEvents': _scrollEvents,
      'errorRate': _imageLoadCount > 0 
          ? _imageLoadErrors / _imageLoadCount * 100
          : 0.0,
    };
  }
}