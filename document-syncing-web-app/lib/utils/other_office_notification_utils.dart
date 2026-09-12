import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// GLOBAL NOTIFIER
final ValueNotifier<int> reprintBadgeNotifier = ValueNotifier<int>(0);

class OtherOfficeNotificationUtils {
  static final _audioPlayer = AudioPlayer();
  static final supabase = Supabase.instance.client;
  
  static bool _isInitialized = false;
  static RealtimeChannel? _reprintChannel;

  // SYNC INITIAL COUNT
  static Future<void> syncInitialCount(String officeName) async {
    try {
      final response = await supabase
          .from('qr_reprint_requests')
          .select('id')
          .eq('requested_by_office', officeName)
          .eq('is_read_user', false);

      reprintBadgeNotifier.value = response.length;
      debugPrint("DEBUG: Sync Finished - Reprint Badge: ${reprintBadgeNotifier.value}");
    } catch (e) {
      debugPrint("DEBUG: Sync Error: $e");
    }
  }

  // INITIALIZE LISTENER
  static void initializeListener(String officeName) {
    if (_isInitialized) return;

    _reprintChannel = supabase
        .channel('public:qr_reprint_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'qr_reprint_requests',
          callback: (payload) async {
            final record = payload.newRecord.isEmpty ? payload.oldRecord : payload.newRecord;

            if (record['requested_by_office']?.toString() == officeName) {
              
              await syncInitialCount(officeName);

              bool isUnread = record['is_read_user'] == false;
              String status = record['status']?.toString().toLowerCase() ?? 'pending';

              if (isUnread && status != 'pending') {
                try {
                  await _audioPlayer.stop();
                  await _audioPlayer.play(AssetSource('sounds/notification-sound.mp3'));
                } catch (e) {
                  debugPrint("Audio Error: $e");
                }
              }
            }
          },
        )
        .subscribe();

    _isInitialized = true;
    debugPrint("DEBUG: Other Office Listeners Initialized.");
  }

  /// RESET (For Logout)
  static void resetAll() {
    if (_reprintChannel != null) {
      supabase.removeChannel(_reprintChannel!);
    }
    _reprintChannel = null;
    _isInitialized = false;
    reprintBadgeNotifier.value = 0;
  }
}