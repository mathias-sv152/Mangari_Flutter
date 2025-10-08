abstract class IHitomiRepository {
  Future<List<Map<String, dynamic>>> getManga(int page);
  Future<Map<String, dynamic>?> getGallery(int galleryId);
  Future<Map<String, dynamic>?> getGGData();
}
