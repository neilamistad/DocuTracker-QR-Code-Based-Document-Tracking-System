import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/login_page.dart';
import 'pages/main_page.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wknwjhtdooengupcuocl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbndqaHRkb29lbmd1cGN1b2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNDM2NjUsImV4cCI6MjA4NTgxOTY2NX0.6eeRL6A3DuuzUU5eAa8vevLwZWuJFY3RXAWL0FEJJMY',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else {
    print('User declined or has not accepted permission');
  }

  Map<String, String>? session = await SessionManager.getSession();

  runApp(QBDTSApp(session: session));
}

class QBDTSApp extends StatelessWidget {
  final Map<String, String>? session;

  const QBDTSApp({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CvSU-CCAT Document Syncing',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: session != null 
        ? OtherOfficeMainPage(
            officeName: session!['name']!, 
            officeId: session!['id']!,
          ) 
        : const OtherOfficeLoginPage(),
    );
  }
}

class SessionManager {
  static const String _keyOfficeName = 'logged_office_name';
  static const String _keyOfficeId = 'logged_office_id';

  static Future<void> saveLogin(String officeName, String officeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOfficeName, officeName);
    await prefs.setString(_keyOfficeId, officeId);
    debugPrint(prefs.getString(_keyOfficeId));
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyOfficeName);
    final id = prefs.getString(_keyOfficeId);
    
    if (name != null && id != null) {
      return {'name': name, 'id': id};
    }
    return null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfficeName);
    await prefs.remove(_keyOfficeId);
  }
}