class EditorialEntity {
  final String editorialName;
  final String editorialLink;
  final String dateRelease;

  const EditorialEntity({
    required this.editorialName,
    required this.editorialLink,
    this.dateRelease = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorialEntity &&
          runtimeType == other.runtimeType &&
          editorialName == other.editorialName &&
          editorialLink == other.editorialLink &&
          dateRelease == other.dateRelease;

  @override
  int get hashCode =>
      editorialName.hashCode ^ editorialLink.hashCode ^ dateRelease.hashCode;

  @override
  String toString() =>
      'EditorialEntity(editorialName: $editorialName, editorialLink: $editorialLink, dateRelease: $dateRelease)';
}