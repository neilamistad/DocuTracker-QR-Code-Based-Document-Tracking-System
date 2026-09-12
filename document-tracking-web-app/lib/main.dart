import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'widgets/main_wrapper.dart';
import 'widgets/admin_main_wrapper.dart';

import 'pages/user_type_page.dart';
import 'pages/dummy_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(

    url: 'https://wknwjhtdooengupcuocl.supabase.co',

    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrbndqaHRkb29lbmd1cGN1b2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNDM2NjUsImV4cCI6MjA4NTgxOTY2NX0.6eeRL6A3DuuzUU5eAa8vevLwZWuJFY3RXAWL0FEJJMY',

  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("FCM DATA: ${message.data}");
  });

  runApp(const QBDTSApp());
}

class QBDTSApp extends StatelessWidget {
  const QBDTSApp({super.key});

  Future<Map<String, dynamic>?> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('userId');
    final String? userType = prefs.getString('userType');
    final bool isFirstTime = prefs.getBool('isFirstTime') ?? false;

    if (userId != null && userType != null) {
      return {
        'userId': userId, 
        'userType': userType, 
        'isFirstTime': isFirstTime
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CvSU-CCAT Document Tracking System',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data!;
            final String userId = data['userId'];
            final String userType = data['userType'];
            final bool isFirstTime = data['isFirstTime'] ?? false;

            // ADMIN LOGIC
            if (userType == 'admin') {
              return const AdminMainWrapper();
            }
            
            // USERS LOGIC
            if (isFirstTime) {
              return DummyDashboardPage(userId: userId, userType: userType);
            } else {
              return MainWrapper(userId: userId, userType: userType);
            }
          }

          return const UserTypePage();
        },
      ),
    );
  }
}