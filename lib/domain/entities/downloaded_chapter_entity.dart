/// Entidad que representa un capítulo descargado localmente
class DownloadedChapterEntity {
  final int? id; // ID local en la base de datos
  final String mangaId; // ID del manga
  final String serverId; // ID del servidor
  final String chapterNumber; // Número del capítulo
  final String chapterTitle; // Título del capítulo
  final String editorial; // Editorial descargada
  final String localPath; // Ruta local donde se guardó
  final int totalPages; // Total de páginas descargadas
  final DateTime downloadedAt; // Fecha de descarga
  final bool isComplete; // Si la descarga está completa

  const DownloadedChapterEntity({
    this.id,
    required this.mangaId,
    required this.serverId,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.editorial,
    required this.localPath,
    required this.totalPages,
    required this.downloadedAt,
    this.isComplete = true,
  });

  DownloadedChapterEntity copyWith({
    int? id,
    String? mangaId,
    String? serverId,
    String? chapterNumber,
    String? chapterTitle,
    String? editorial,
    String? localPath,
    int? totalPages,
    DateTime? downloadedAt,
    bool? isComplete,
  }) {
    return DownloadedChapterEntity(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      serverId: serverId ?? this.serverId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      editorial: editorial ?? this.editorial,
      localPath: localPath ?? this.localPath,
      totalPages: totalPages ?? this.totalPages,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Convierte la entidad a un Map para guardar en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'server_id': serverId,
      'chapter_number': chapterNumber,
      'chapter_title': chapterTitle,
      'editorial': editorial,
      'local_path': localPath,
      'total_pages': totalPages,
      'downloaded_at': downloadedAt.toIso8601String(),
      'is_complete': isComplete ? 1 : 0,
    };
  }

  /// Crea una entidad desde un Map de la base de datos
  factory DownloadedChapterEntity.fromMap(Map<String, dynamic> map) {
    return DownloadedChapterEntity(
      id: map['id'] as int?,
      mangaId: map['manga_id'] as String,
      serverId: map['server_id'] as String,
      chapterNumber: map['chapter_number'] as String,
      chapterTitle: map['chapter_title'] as String,
      editorial: map['editorial'] as String,
      localPath: map['local_path'] as String,
      totalPages: map['total_pages'] as int,
      downloadedAt: DateTime.parse(map['downloaded_at'] as String),
      isComplete: (map['is_complete'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedChapterEntity &&
          runtimeType == other.runtimeType &&
          mangaId == other.mangaId &&
          serverId == other.serverId &&
          chapterNumber == other.chapterNumber &&
          editorial == other.editorial;

  @override
  int get hashCode =>
      mangaId.hashCode ^
      serverId.hashCode ^
      chapterNumber.hashCode ^
      editorial.hashCode;

  @override
  String toString() =>
      'DownloadedChapterEntity(manga: $mangaId, chapter: $chapterNumber, editorial: $editorial, complete: $isComplete)';
}
