import 'package:flutter/foundation.dart';

/// Preparation for a meeting that has already been agreed.
///
/// Four fields, in the order they are read: why this half-hour is worth taking,
/// what to ask, what the other side will ask you, and the one thing to have
/// ready. Not a summary of the two cards — both parties can already read those
/// — but the thing neither card contains, which is what to *do* with the hour.
///
/// Held as a value with no model or timestamp on it. The sheet needs to know
/// which engine produced it, but the brief itself is just the words.
@immutable
class MeetingBrief {
  const MeetingBrief({
    required this.why,
    required this.questions,
    required this.theirAsk,
    required this.prep,
  });

  /// One sentence on what makes the pairing worth the slot.
  final String why;

  /// Up to three questions, specific to the counterpart's card.
  final List<String> questions;

  /// What the other side is most likely to want out of this.
  final String theirAsk;

  /// The one concrete thing to walk in holding.
  final String prep;

  /// A brief with no questions is not a brief — the questions are the only part
  /// that changes what happens in the room, so a response missing them is
  /// rejected here rather than rendered as an empty list.
  static MeetingBrief? fromMap(Map<Object?, Object?> map) {
    final questions = [
      for (final question in (map['questions'] as List?) ?? const [])
        if (question is String && question.trim().isNotEmpty) question.trim(),
    ];
    if (questions.isEmpty) return null;

    return MeetingBrief(
      why: ((map['why'] as String?) ?? '').trim(),
      questions: questions,
      theirAsk: ((map['theirAsk'] as String?) ?? '').trim(),
      prep: ((map['prep'] as String?) ?? '').trim(),
    );
  }
}
