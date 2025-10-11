abstract class IHitomiRepository {
  Future<List<Map<String, dynamic>>> getManga(int page);
  Future<Map<String, dynamic>?> getGallery(int galleryId);
  Future<Map<String, dynamic>?> getGGData();
  Future<List<Map<String, dynamic>>> searchManga(String query, int page);
  Future<List<Map<String, dynamic>>> searchMangaWithFilters(
    String query,
    int page, {
    String? orderBy,
    String? orderByKey,
  });
}
