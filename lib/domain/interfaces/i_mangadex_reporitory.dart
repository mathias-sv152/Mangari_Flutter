abstract class IMangaDexRepository {
  Future<Map<String, dynamic>> getManga(int page);
  Future<Map<String, dynamic>> getMangaDetail(String mangaId);
  Future<Map<String, dynamic>> getChapters(String mangaId);
  Future<Map<String, dynamic>> getChapterDetail(String chapterId);
}
