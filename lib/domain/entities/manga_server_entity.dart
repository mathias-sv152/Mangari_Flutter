/// Entidad de dominio para Manga Server
/// Representa un servidor de manga en el sistema
class MangaServerEntity {
  final String id;
  final String name;
  final String url;
  final String description;
  final bool isActive;
  final int mangaCount;
  final String iconUrl;
  final List<String> supportedLanguages;
  final DateTime lastUpdated;

  MangaServerEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.description,
    required this.isActive,
    required this.mangaCount,
    required this.iconUrl,
    required this.supportedLanguages,
    required this.lastUpdated,
  });

  @override
  String toString() {
    return 'MangaServerEntity(id: $id, name: $name, url: $url, isActive: $isActive)';
  }
}