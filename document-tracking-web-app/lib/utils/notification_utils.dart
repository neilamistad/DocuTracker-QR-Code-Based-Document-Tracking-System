import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// GLOBAL NOTIFIERS
final ValueNotifier<int> trackingBadgeNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> deletionBadgeNotifier = ValueNotifier<int>(0);
final ValueNotifier<Map<String, dynamic>?> passwordRequestStatusNotifier = ValueNotifier<Map<String, dynamic>?>(null);

class NotificationUtils {
  static final _audioPlayer = AudioPlayer();
  
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static RealtimeChannel? _trackingChannel;
  static RealtimeChannel? _deletionChannel;
  static RealtimeChannel? _passwordChannel;

  // SYNC INITIAL COUNTS
  static Future<void> syncInitialBadgeCounts(String userId) async {
    final supabase = Supabase.instance.client;

    try {
      final results = await Future.wait<dynamic>([
        supabase
            .from('tracking_history')
            .select('history_id')
            .eq('registered_by_id', userId)
            .eq('is_read', false),
        supabase
            .from('document_deletion_requests')
            .select('id')
            .eq('requested_by', userId)
            .eq('is_read_user', false),
        supabase
            .from('password_requests')
            .select('status, is_read_user')
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      trackingBadgeNotifier.value = results[0].length;
      deletionBadgeNotifier.value = results[1].length;
      passwordRequestStatusNotifier.value = results[2] as Map<String, dynamic>?;

      debugPrint("DEBUG: Sync Finished - Tracking: ${trackingBadgeNotifier.value}, Password: ${passwordRequestStatusNotifier.value}");
    } catch (e) {
      debugPrint("DEBUG: Sync Error: $e");
    }
  }

  // INITIALIZE LISTENERS
  static void initializeListeners(String userId) {
    if (_isInitialized) return;
    final supabase = Supabase.instance.client;

    // TRACKING HISTORY LISTENER
    _trackingChannel = supabase.channel('public:tracking_history').onPostgresChanges(
      event: PostgresChangeEvent.all, // LISTEN TO ALL CHANGES (Insert/Delete/Update)
      schema: 'public',
      table: 'tracking_history',
      callback: (payload) async {
        // LISTENING IF INSERT/UPDATE, oldRecord IF DELETE
        final record = payload.newRecord.isEmpty ? payload.oldRecord : payload.newRecord;

        if (record['registered_by_id']?.toString() == userId) {
          // FORCE SYNC OF COUNTERS FROM DATABASE
          await syncInitialBadgeCounts(userId);

          if ((payload.eventType == PostgresChangeEvent.insert && record['is_read'] == false) || (record['is_corrected'] == true && record['is_read'] == false)) {
            _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
          }
        }
      },
    ).subscribe();

    // DELETION REQUESTS LISTENER
    _deletionChannel = supabase.channel('public:document_deletion_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_deletion_requests',
      callback: (payload) async {
        final record = payload.newRecord.isEmpty ? payload.oldRecord : payload.newRecord;

        if (record['requested_by']?.toString() == userId && record['status'].toString() != "pending") {
          await syncInitialBadgeCounts(userId);

          if (record['is_read_user'] == false ) {
            _audioPlayer.stop();
            _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
          }
        }
      },
    ).subscribe();

    // PASSWORD CHANGE REQUESTS LISTENER
    _passwordChannel = supabase.channel('public:password_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'password_requests',
      callback: (payload) async {
        final record = payload.newRecord.isEmpty ? payload.oldRecord : payload.newRecord;
        
        if (record['user_id']?.toString() == userId) {
          debugPrint("Realtime Update Received: ${payload.eventType}");

          await syncInitialBadgeCounts(userId);
          
          passwordRequestStatusNotifier.value = Map<String, dynamic>.from(record);

          final bool isRead = record['is_read_user'] == false;
          final String status = record['status']?.toString().toLowerCase() ?? '';

          if (isRead && status != 'pending' && status != '') {

            if (status != 'applied'){
               debugPrint("Playing sound for status: $status");
              try {
                await _audioPlayer.stop();
                await _audioPlayer.play(AssetSource('sounds/notification_sound.mp3'));
              } catch (e) {
                debugPrint("Audio Error: $e");
              }
            }
          }
        }
      },
    ).subscribe();

    _isInitialized = true;
    debugPrint("DEBUG: Notification Listeners Initialized.");
  }

  // CLEAR BADGES
  static void clearTrackingBadge() {
    trackingBadgeNotifier.value = 0;
  }

  static void clearDeletionBadge() {
    deletionBadgeNotifier.value = 0;
  }

  static void clearPasswordBadge() {
    if (passwordRequestStatusNotifier.value != null) {
      final updatedData = Map<String, dynamic>.from(passwordRequestStatusNotifier.value!);
      updatedData['is_read_user'] = true;
      passwordRequestStatusNotifier.value = updatedData;
    }
  }
  // RESET ALL (For Logout)
  static Future<void> resetAll() async {
    final supabase = Supabase.instance.client;

    // PROPER UNSUBSCRIBING
    if (_trackingChannel != null) {
      await supabase.removeChannel(_trackingChannel!);
    }
    if (_deletionChannel != null) {
      await supabase.removeChannel(_deletionChannel!);
    }
    if (_passwordChannel != null) {
      await supabase.removeChannel(_passwordChannel!);
    }
    
    // CLEANING UP AUDIO RESOURCES
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Audio cleanup error: $e");
    }

    // NULLIFY CHANNELS
    _trackingChannel = null;
    _deletionChannel = null;
    _passwordChannel = null;
    _isInitialized = false;

    // RESET NOTIFIERS TO DEFAULT (Pure state reset)
    trackingBadgeNotifier.value = 0;
    deletionBadgeNotifier.value = 0;
    passwordRequestStatusNotifier.value = null;

    debugPrint("DEBUG: Notification System Fully Reset.");
  }
}