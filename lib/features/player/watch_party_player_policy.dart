import '../../core/watch_party/watch_party_models.dart';

/// Player actions cannot silently turn an active guest into a local session.
/// Changing the room episode remains a host action, including after awaits.
String? watchPartyPlayerChangeError({
  required WatchPartySnapshot? room,
  required WatchPartyMedia currentMedia,
  required String videoId,
  WatchPartySource? source,
  bool checkSource = false,
}) {
  if (room == null || room.media == null || room.isHost) return null;
  if (room.media!.key != currentMedia.key) return 'partyTitleChanged';
  if (videoId != currentMedia.videoId) return 'partyGuestEpisodeLocked';
  if (checkSource &&
      room.sourceLocked &&
      (source == null || source.key != room.source?.key)) {
    return 'partySourceLockedMismatch';
  }
  return null;
}
