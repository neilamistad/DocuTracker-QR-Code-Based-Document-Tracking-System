import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ADMIN GLOBAL NOTIFIERS
final ValueNotifier<int> adminPasswordRequestNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> adminDeletionRequestNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> adminQRReprintNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> adminFacultyRequestNotifier = ValueNotifier<int>(0);

class AdminNotificationUtils {
  static final _audioPlayer = AudioPlayer();
  static RealtimeChannel? _passwordChannel;
  static RealtimeChannel? _deletionChannel;
  static RealtimeChannel? _qrReprintChannel;
  static RealtimeChannel? _facultyRequestChannel;
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;
  static bool _isSyncing = false;

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initAdminLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
    );
    debugPrint("ADMIN DEBUG: Local Notifications Initialized.");
  }

  static void showAdminNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Admin Alert',
      body: message.notification?.body ?? '',
      notificationDetails: platformChannelSpecifics,
    );
  }

  // SYNC INITIAL COUNTS
  static Future<void> syncAdminBadgeCounts() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final supabase = Supabase.instance.client;

    try {
      final results = await Future.wait([
        supabase
          .from('password_requests')
          .select('id')
          .eq('is_read_admin', false),

        supabase
          .from('document_deletion_requests')
          .select('id')
          .eq('is_read_admin', false),

        supabase
          .from('qr_reprint_requests')
          .select('id')
          .eq('is_read_admin', false), 

        supabase
          .from('faculty_account_registration_requests')
          .select('faculty_id')
          .eq('is_read_admin', false),
      ]);

      adminPasswordRequestNotifier.value = results[0].length;
      adminDeletionRequestNotifier.value = results[1].length;
      adminQRReprintNotifier.value = results[2].length;
      adminFacultyRequestNotifier.value = results[3].length;

      debugPrint("ADMIN SYNC: PW: ${results[0].length}, Del: ${results[1].length}, QR: ${results[2].length}, Faculty: ${results[3].length}");
    } catch (e) {
      debugPrint("ADMIN SYNC Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // INITIALIZE ADMIN LISTENERS
  static void initializeAdminListeners() {
    if (_isInitialized) return;
    final supabase = Supabase.instance.client;

    // PASSWORD REQUESTS
    _passwordChannel = supabase.channel('admin:password_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'password_requests',
      callback: (payload) async {
        await syncAdminBadgeCounts();
        /*if (payload.eventType == PostgresChangeEvent.insert) {
          _audioPlayer.play(AssetSource('sounds/notification-sound.mp3'));
        }*/
      },
    ).subscribe();

    // DELETION REQUESTS
    _deletionChannel = supabase.channel('admin:document_deletion_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_deletion_requests',
      callback: (payload) async {
        await syncAdminBadgeCounts();
        /*if (payload.eventType == PostgresChangeEvent.insert) {
          await _audioPlayer.stop();
          _audioPlayer.play(AssetSource('sounds/notification-sound.mp3'));
        }*/
      },
    ).subscribe();

    // QR REPRINT REQUESTS
    _qrReprintChannel = supabase.channel('admin:qr_reprint_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'qr_reprint_requests',
      callback: (payload) async {
        await syncAdminBadgeCounts();
        /*if (payload.eventType == PostgresChangeEvent.insert) {
          await _audioPlayer.stop();
          _audioPlayer.play(AssetSource('sounds/notification-sound.mp3'));
        }*/
      },
    ).subscribe();

    // FACULTY ACCOUNT REQUESTS
    _facultyRequestChannel = supabase.channel('admin:faculty_account_registration_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'faculty_account_registration_requests',
      callback: (payload) async {
        await syncAdminBadgeCounts();
        /*if (payload.eventType == PostgresChangeEvent.insert) {
          await _audioPlayer.stop();
          _audioPlayer.play(AssetSource('sounds/notification-sound.mp3'));
        }*/
      },
    ).subscribe();

    _isInitialized = true;
    debugPrint("ADMIN DEBUG: All Listeners Initialized.");
  }

  static Future<void> resetAdminNotificationUtils() async {
    final supabase = Supabase.instance.client;
    
    if (_passwordChannel != null) await supabase.removeChannel(_passwordChannel!);
    if (_deletionChannel != null) await supabase.removeChannel(_deletionChannel!);
    if (_qrReprintChannel != null) await supabase.removeChannel(_qrReprintChannel!);
    if (_facultyRequestChannel != null) await supabase.removeChannel(_facultyRequestChannel!);
    
    _passwordChannel = null;
    _deletionChannel = null;
    _qrReprintChannel = null;
    _facultyRequestChannel = null;
    _isInitialized = false;

    adminPasswordRequestNotifier.value = 0;
    adminDeletionRequestNotifier.value = 0;
    adminQRReprintNotifier.value = 0;
    adminFacultyRequestNotifier.value = 0;
    
    await _audioPlayer.stop();
  }
}