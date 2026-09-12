import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'utils/user_notifications.dart';
import 'utils/admin_notifications.dart';

import 'widgets/user_navigation_bar_wrapper.dart';
import 'widgets/admin_navigation_bar_wrapper.dart';

import 'get_started_page.dart';
import 'usertype_page.dart';
import 'user/user_dummy_dashboard_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final supabase = Supabase.instance.client;

  final String? docId = message.data['docId'];

  final prefs = await SharedPreferences.getInstance();
  final String? userType = prefs.getString('userType');

  if (docId != null) {
    try {
      final DateTime receiveTime = DateTime.now();
  
      final response = await supabase
          .from('sync_notif_speed_logs')
          .update({'receive_time_by_mobile_app': receiveTime.toIso8601String()})
          .eq('document_id', docId)
          .filter('receive_time_by_mobile_app', 'is', null)
          .select();

      if (response.isNotEmpty) {
        print("Latency Logged for Doc: $docId");
      }
    } catch (e) {
      print("Logging Error: $e");
    }

    if (userType == 'admin') {
      AdminNotificationUtils.showAdminNotification(message);
    } else {
      UserNotificationUtils.showNotification(message);
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await Supabase.initialize(
    url: 'https://wknwjhtdooengupcuocl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbndqaHRkb29lbmd1cGN1b2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNDM2NjUsImV4cCI6MjA4NTgxOTY2NX0.6eeRL6A3DuuzUU5eAa8vevLwZWuJFY3RXAWL0FEJJMY',
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'), 
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  try {
    await Firebase.initializeApp(); 
    print("Firebase Initialized Successfully");

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  } catch (e) {
    print("Firebase Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final supabase = Supabase.instance.client;
  
  @override
  void initState() {
    super.initState();
    _setupInteractedMessage();
    
    // FOREGROUND LISTENER
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final String? docId = message.data['docId'];

      final prefs = await SharedPreferences.getInstance();
      final String? userType = prefs.getString('userType');

      if (docId != null) {
        try {
          final DateTime receiveTime = DateTime.now();
      
          final response = await supabase
              .from('sync_notif_speed_logs')
              .update({'receive_time_by_mobile_app': receiveTime.toIso8601String()})
              .eq('document_id', docId)
              .filter('receive_time_by_mobile_app', 'is', null)
              .select();

          if (response.isNotEmpty) {
            print("Latency Logged for Doc: $docId");
          }
        } catch (e) {
          print("Logging Error: $e");
        }
      }

      if (userType == 'admin') {
        AdminNotificationUtils.showAdminNotification(message);
      } else {
        UserNotificationUtils.showNotification(message);
      }
    });
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationClick(initialMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  void _handleNotificationClick(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userType = prefs.getString('userType');
    final String? userId = prefs.getString('userId');

    print("Notification clicked! UserType: $userType");

    if (userType == 'admin') {
      AdminNotificationUtils.syncAdminBadgeCounts();
    } else {
      UserNotificationUtils.syncInitialBadgeCounts(userId!);
    }
  }

  Future<Map<String, dynamic>> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final bool isAppFirstTime = prefs.getBool('isAppFirstTime') ?? true;
    final String? userId = prefs.getString('userId');
    final String? userType = prefs.getString('userType');
    final bool isUserFirstLogin = prefs.getBool('isFirstTime') ?? false;

    return {
      'isAppFirstTime': isAppFirstTime,
      'userId': userId,
      'userType': userType,
      'isUserFirstLogin': isUserFirstLogin,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Department of Engineering Document Tracking System',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _checkAppState(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFF8BB839))),
            );
          }

          final data = snapshot.data!;
          final bool isAppFirstTime = data['isAppFirstTime'];
          final String? userId = data['userId'];
          final String? userType = data['userType'];
          final bool isUserFirstLogin = data['isUserFirstLogin'];

          if (isAppFirstTime) {
            return const GetStartedScreen();
          }

          if (userId != null && userType != null) {
            if (userType == 'admin') {
              return const AdminNavigationBarWrapper();
            }
            
            if (isUserFirstLogin) {
              return UserDummyDashboardPage(userId: userId, userType: userType);
            } else {
              return UserNavigationBarWrapper(userId: userId, userType: userType);
            }
          }

          return const UserTypePage();
        },
      ),
    );
  }
}