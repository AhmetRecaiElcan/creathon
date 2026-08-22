import 'dart:math';

/// Names the room an online meeting is held in.
///
/// Only the name lives here. The link is built and signed by the
/// `meetingJoinLink` function, because reaching a JaaS room needs a JWT signed
/// with the tenant's RSA private key — and a private key in the app is a
/// private key anyone who unzips the APK can use against the tenant. So the app
/// knows what the room is called and nothing else about how to get in; see
/// [MeetingLinkRepository].
///
/// The public instance was the first attempt and reads better on paper: a bare
/// `meet.jit.si/<room>` URL, no account, no key, no server. It asks whoever
/// opens the room first to sign in with a Google or GitHub account, which is
/// not something to put in front of an investor who came here to take one call.
abstract final class MeetingRoom {
  /// Prefixed so a room is recognisable in a link, and so a name can never
  /// collide with the short ones people pick by hand.
  static const _prefix = 'takeoff';

  /// Ambiguous glyphs left out: these names get read aloud and retyped off a
  /// screen, and `l`/`1` or `O`/`0` is where that goes wrong.
  static const _alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';

  static const _length = 14;

  /// A fresh room name.
  ///
  /// Random rather than derived from the meeting's id, even though the id is
  /// already unique. The signed token is what keeps strangers out now, but the
  /// name still must not be computable from an organisation id and a clock
  /// time: a guessable room is one bug in the token check away from an open
  /// door, and there is no reason to build that dependency in the first place.
  /// 14 characters of a 32-symbol alphabet is 70 bits.
  static String newName() {
    final random = Random.secure();
    final chars = [
      for (var i = 0; i < _length; i++)
        _alphabet[random.nextInt(_alphabet.length)],
    ];
    return '$_prefix-${chars.join()}';
  }
}
