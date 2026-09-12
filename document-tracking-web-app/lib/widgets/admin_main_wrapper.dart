import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../utils/admin_notification_utils.dart';

import 'app_background.dart';

import '../admin-pages/admin_dashboard_page.dart';
import '../admin-pages/admin_document_search_page.dart';
import '../admin-pages/admin_settings_page.dart';

class AdminMainWrapper extends StatefulWidget {

  const AdminMainWrapper({
    super.key,
  });

  @override
  State<AdminMainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<AdminMainWrapper> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const AdminDashboardPage(),
    const AdminDocumentSearchPage(),
    const AdminSettingsPage(),
  ];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    

    Future.delayed(Duration.zero, () async {
      await AdminNotificationUtils.syncAdminBadgeCounts();
      
      if (!AdminNotificationUtils.isInitialized) {
        AdminNotificationUtils.initializeAdminListeners();
      }
    });

    // FIREBASE NOTIFICATION SETUP (Cloud Push)
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? loggedInUsername = prefs.getString('userId');

      if (loggedInUsername == null) {
        debugPrint("FCM: No logged in user found in prefs.");
        return;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FCM: Foreground message received!");
        
        AdminNotificationUtils.syncAdminBadgeCounts();

        String title = message.notification?.title ?? message.data['title'] ?? 'CvSU DocuTracker';
        String body = message.notification?.body ?? message.data['body'] ?? 'New update received.';
        
        String fullMessage = "$title: $body";
        debugPrint("Foreground Message: $fullMessage");

        if (mounted) {
          _showTopNotification(
            fullMessage, 
            const Color(0xFF1B5E20),
          );
        }
      });

    } catch (e) {
      debugPrint("Error setting up push notifications: $e");
    }
  }

  void _showTopNotification(String msg, Color color) {
    if (!mounted) return;

    try {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
        displayDuration: const Duration(seconds: 3),
        curve: Curves.elasticOut, 
        reverseCurve: Curves.linear,
      );
    } catch (e) {
      debugPrint("Snackbar error ignored: $e");
    }
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Gawing transparent ang background ng Scaffold
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Column( // TANGGALIN ang SafeArea dito
          children: [
            // 2. Manual padding para sa status bar para hindi dikit sa taas ang buttons
            SizedBox(height: MediaQuery.of(context).padding.top + 10),
            
            _buildHeaderNav(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavButton(
              label: 'Dashboard',
              isActive: _selectedIndex == 0,
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            _NavButton(
              label: 'Document Search',
              isActive: _selectedIndex == 1,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            
            // ADMIN SETTINGS WITH AGGREGATED NOTIFICATIONS
            ListenableBuilder(
              listenable: Listenable.merge([
                adminPasswordRequestNotifier,
                adminDeletionRequestNotifier,
                adminQRReprintNotifier,
                adminFacultyRequestNotifier,
              ]),
              builder: (context, child) {

                final totalRequests = adminPasswordRequestNotifier.value +
                                    adminDeletionRequestNotifier.value +
                                    adminQRReprintNotifier.value +
                                    adminFacultyRequestNotifier.value;

                return _NavButton(
                  label: 'Admin Settings',
                  isActive: _selectedIndex == 2,
                  badge: totalRequests > 0 
                      ? (totalRequests > 99 ? "99+" : totalRequests.toString()) 
                      : null,
                  onTap: () => setState(() => _selectedIndex = 2),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// SUPPORTING WIDGETS

class _NavButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  const _NavButton({
    required this.label,
    this.isActive = false,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(2300),
            child: CustomPaint(
              painter: isActive ? _GradientBorderPainter() : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.12) : const Color(0x14D9D9D9),
                  borderRadius: BorderRadius.circular(2300),
                  border: !isActive ? Border.all(color: Colors.white.withOpacity(0.4), width: 1) : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..shader = const LinearGradient(
        begin: Alignment(-0.5, 0.866),
        end: Alignment(0.5, -0.866),
        colors: [Color(0xFF78CF4E), Color(0xFF51AC80)],
      ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2300));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}