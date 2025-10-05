import '../entities/manga_detail_entity.dart';
import '../entities/chapter_view_entity.dart';

abstract class IMangaRepository {
  Future<Map<String, dynamic>> getManga(int page);
  Future<Map<String, dynamic>> getMangaDetail(String mangaId);
  Future<Map<String, dynamic>> getChapters(String mangaId);
  Future<Map<String, dynamic>> getChapterDetail(String chapterId);
}

abstract class IMangaService {
  Future<List<MangaDetailEntity>> getManga(int page);
  Future<MangaDetailEntity> getMangaDetail(MangaDetailEntity manga);
  Future<List<String>> getChapterImages(ChapterViewEntity chapter);
}