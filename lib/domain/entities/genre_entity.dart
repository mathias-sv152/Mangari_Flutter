class GenreEntity {
  final String text;
  final String href;

  const GenreEntity({
    required this.text,
    required this.href,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenreEntity &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          href == other.href;

  @override
  int get hashCode => text.hashCode ^ href.hashCode;

  @override
  String toString() => 'GenreEntity(text: $text, href: $href)';
}