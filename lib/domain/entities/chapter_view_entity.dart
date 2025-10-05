class ChapterViewEntity {
  final String editorialLink;
  final String editorialName;
  final String chapterTitle;

  const ChapterViewEntity({
    required this.editorialLink,
    required this.editorialName,
    required this.chapterTitle,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterViewEntity &&
          runtimeType == other.runtimeType &&
          editorialLink == other.editorialLink;

  @override
  int get hashCode => editorialLink.hashCode;

  @override
  String toString() =>
      'ChapterViewEntity(editorialLink: $editorialLink, editorialName: $editorialName, chapterTitle: $chapterTitle)';
}