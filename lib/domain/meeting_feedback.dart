import 'package:flutter/foundation.dart';

/// One party's verdict on a meeting that has happened.
///
/// Written once and never edited: a rating you can go back and change is a
/// rating you can be talked into changing, and the point of asking is to learn
/// what the meeting was actually like. Expressing that as a create-only
/// document lets the security rules enforce it rather than the UI merely
/// declining to offer an edit button.
///
/// Each side rates independently and neither sees the other's — see the
/// `meetingFeedback` rules. Mutual visibility turns a rating into a courtesy
/// score, where everyone gives five stars and the data says nothing.
@immutable
class MeetingFeedback {
  const MeetingFeedback({
    required this.id,
    required this.meetingId,
    required this.authorId,
    required this.organizationId,
    required this.counterpartName,
    required this.rating,
    required this.submittedAt,
    this.note,
  });

  final String id;

  final String meetingId;

  /// Who is rating. One feedback per party per meeting, which is what the
  /// document id expresses.
  final String authorId;

  /// The card the meeting was with. Copied on so the organiser can group
  /// ratings by company without a second read per row.
  final String organizationId;

  /// Who the author met, in words. The author is shown their own history and
  /// "4 yıldız" against nothing would be unreadable.
  final String counterpartName;

  /// One to five. Validated in the rules too — a rating outside that range
  /// would quietly poison any average taken over the collection.
  final int rating;

  /// What they wanted to say, if anything. The stars are compulsory because
  /// they can be given in one tap; the words are not, because demanding them
  /// is how you get "iyiydi" from everyone.
  final String? note;

  final DateTime submittedAt;

  static const minRating = 1;
  static const maxRating = 5;

  static bool isValidRating(int rating) =>
      rating >= minRating && rating <= maxRating;

  /// `{meetingId}__{authorId}` — makes "one rating per person per meeting" a
  /// property of the document's name, so a create on a second attempt is
  /// refused by Firestore instead of overwriting the first.
  static String idFor({
    required String meetingId,
    required String authorId,
  }) => '${meetingId}__$authorId';

  Map<String, Object?> toMap() => {
    'meetingId': meetingId,
    'authorId': authorId,
    'organizationId': organizationId,
    'counterpartName': counterpartName,
    'rating': rating,
    'note': note,
    'submittedAt': submittedAt.toIso8601String(),
  };

  /// Returns null when the row cannot be read, so one malformed document does
  /// not hide every meeting the user has already rated — which would make them
  /// all reappear asking to be rated again.
  static MeetingFeedback? fromMap(
    Map<String, Object?> map, {
    required String id,
  }) {
    final meetingId = map['meetingId'] as String?;
    final authorId = map['authorId'] as String?;
    final rating = (map['rating'] as num?)?.toInt();
    if (meetingId == null || authorId == null || rating == null) return null;

    return MeetingFeedback(
      id: id,
      meetingId: meetingId,
      authorId: authorId,
      organizationId: (map['organizationId'] as String?) ?? '',
      counterpartName: (map['counterpartName'] as String?) ?? 'Katılımcı',
      rating: rating,
      note: map['note'] as String?,
      submittedAt:
          DateTime.tryParse((map['submittedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
