import 'editorial_entity.dart';

class ChapterEntity {
  final String numAndTitleCap;
  final String dateRelease;
  final List<EditorialEntity> editorials;
  final bool isViewed;

  const ChapterEntity({
    required this.numAndTitleCap,
    required this.dateRelease,
    required this.editorials,
    this.isViewed = false,
  });

  ChapterEntity copyWith({
    String? numAndTitleCap,
    String? dateRelease,
    List<EditorialEntity>? editorials,
    bool? isViewed,
  }) {
    return ChapterEntity(
      numAndTitleCap: numAndTitleCap ?? this.numAndTitleCap,
      dateRelease: dateRelease ?? this.dateRelease,
      editorials: editorials ?? this.editorials,
      isViewed: isViewed ?? this.isViewed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEntity &&
          runtimeType == other.runtimeType &&
          numAndTitleCap == other.numAndTitleCap &&
          dateRelease == other.dateRelease &&
          isViewed == other.isViewed;

  @override
  int get hashCode =>
      numAndTitleCap.hashCode ^ dateRelease.hashCode ^ isViewed.hashCode;

  @override
  String toString() =>
      'ChapterEntity(numAndTitleCap: $numAndTitleCap, dateRelease: $dateRelease, editorials: ${editorials.length}, isViewed: $isViewed)';
}