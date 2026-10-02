import '../models/app_version.dart';

/// Whether [announcement] should stay hidden because the user already saw or
/// dismissed it, according to its `frequency`.
///
/// Pure (no clock, storage or Flutter), so the rules are unit-testable.
/// The backend has already chosen which announcements are live and in what
/// order; this only applies the per-user "have they seen it" part.
bool isAnnouncementSuppressed(
  final AnnouncementInfo announcement, {
  required final int? lastSeenMillis,
  required final bool seenThisSession,
  required final DateTime now,
}) {
  // A banner that can't be dismissed is always on screen while it's live.
  if (announcement.isBanner && !announcement.dismissible) return false;

  switch (announcement.frequency) {
    case 'every_launch':
      return seenThisSession;
    case 'daily':
      if (lastSeenMillis == null) return false;
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
      final today = now.toLocal();
      return lastSeen.year == today.year &&
          lastSeen.month == today.month &&
          lastSeen.day == today.day;
    case 'once':
    default:
      return lastSeenMillis != null;
  }
}
