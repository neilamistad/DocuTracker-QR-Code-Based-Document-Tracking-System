import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../utils/notification_utils.dart';
import 'app_background.dart';

import '../user-pages/dashboard_page.dart';
import '../user-pages/document_search_page.dart';
import '../user-pages/document_registration_page.dart';
import '../user-pages/document_tracking_history_page.dart';
import '../user-pages/account_settings_page.dart';

class MainWrapper extends StatefulWidget {
  final String userId;
  final String userType;

  const MainWrapper({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  final supabase = Supabase.instance.client;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    _pages = [
      DashboardPage(userId: widget.userId, userType: widget.userType),
      DocumentSearchPage(userId: widget.userId, userType: widget.userType),
      DocumentRegistrationPage(userId: widget.userId, userType: widget.userType),
      DocumentTrackingHistoryPage(userId: widget.userId, userType: widget.userType),
      UserAccSettingsPage(userId: widget.userId, userType: widget.userType),
    ];

    // NOTIFICATION LOGIC
    Future.delayed(Duration.zero, () async {
      if (!NotificationUtils.isInitialized) {
        await NotificationUtils.syncInitialBadgeCounts(widget.userId);
        NotificationUtils.initializeListeners(widget.userId);
      } else {
        await NotificationUtils.syncInitialBadgeCounts(widget.userId);
      }
    });

    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? loggedInUsername = prefs.getString('userId');
      final String? userType = prefs.getString('userType'); 

      if (loggedInUsername == null || userType == null) {
        debugPrint("FCM: User ID or UserType missing in prefs.");
        return;
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token;

        if (kIsWeb) {
          token = await messaging.getToken(
            vapidKey: "BHZWBDkHQfKqbQg0VzzLZ-DE69fxgBInwDCtRfbqCP8-iTnD4VWnQII-qHqMZQRwve9yOB7cv1VoQG83C2vHjaM" 
          );
        } else {
          token = await messaging.getToken();
        }

        if (token != null) {
          String targetTable = (userType.toLowerCase() == 'faculty') 
              ? 'faculty_accounts' 
              : 'student_org_accounts';

          String idColumn = (userType.toLowerCase() == 'faculty') 
              ? 'faculty_id' 
              : 'org_id';

          final userData = await supabase
              .from(targetTable)
              .select('fcm_token')
              .eq(idColumn, loggedInUsername)
              .maybeSingle();

          if (userData != null) {
            final List<dynamic> rawTokens = userData['fcm_token'] ?? [];
            List<String> updatedTokens = rawTokens.map((e) => e.toString()).toList();

            if (!updatedTokens.contains(token)) {
              updatedTokens.add(token);

              await supabase
                  .from(targetTable)
                  .update({
                    'fcm_token': updatedTokens, 
                  })
                  .eq(idColumn, loggedInUsername);
                  
              debugPrint("FCM Token successfully synced for $userType.");
            }
          }
        }

        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {

          String title = message.notification?.title ?? message.data['title'] ?? 'CvSU DocuTracker';
          String body = message.notification?.body ?? message.data['body'] ?? 'New update received.';

          String fullMessage = "$title: $body";

          if (mounted) {
          _showTopNotification(
            fullMessage, 
            const Color(0xFF1B5E20),
          );
        }

          NotificationUtils.syncInitialBadgeCounts(loggedInUsername);
        });
      }
    } catch (e) {
      debugPrint("Error setting up user push notifications: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await supabase
          .from('tracking_history')
          .update({'is_read': true})
          .eq('registered_by_id', widget.userId)
          .eq('is_read', false);
      
      if (mounted) {
        if (trackingBadgeNotifier.value > 0) {
          _showTopNotification("All updates marked as read", Colors.green);
        }
      }

      trackingBadgeNotifier.value = 0;
    } catch (e) {
      debugPrint("Error: $e");
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
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // UNIVERSAL NAVIGATION BAR
              _buildHeaderNav(),

              // MULTI-PAGE CONTENT AREA
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
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
            _NavButton(
              label: 'Document Registration',
              isActive: _selectedIndex == 2,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
            
            // TRACKING HISTORY BUTTON WITH BADGE
            ValueListenableBuilder<int>(
              valueListenable: trackingBadgeNotifier,
              builder: (context, count, child) {
                return _NavButton(
                  label: 'Tracking History',
                  isActive: _selectedIndex == 3,
                  badge: count > 0 ? (count > 99 ? "99+" : count.toString()) : null,
                  onTap: () {
                    if (_selectedIndex == 3) {
                      print("Refresh and Mark as Read triggered");
                      markAllAsRead();
                    } else {
                      setState(() => _selectedIndex = 3);
                    }
                  },
                );
              },
            ),

            // ACCOUNT SETTINGS WITH RED DOT NOTIFICATION
            ValueListenableBuilder<int>(
              valueListenable: deletionBadgeNotifier,
              builder: (context, deletionCount, child) {
                return ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: passwordRequestStatusNotifier,
                  builder: (context, passwordData, child) {
                    final bool hasUnreadPassword = passwordData?['is_read_user'] == false && 
                                                 passwordData?['status'] != 'pending';
                    final bool showDot = (deletionCount > 0) || hasUnreadPassword;

                    return _NavButton(
                      label: 'Account',
                      isActive: _selectedIndex == 4,
                      badge: showDot ? "dot" : null,
                      onTap: () => setState(() => _selectedIndex = 4),
                    );
                  },
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
          
          // BADGE UI (NUMBER OR DOT)
          if (badge != null)
            Positioned(
              right: badge == "dot" ? 0 : -5,
              top: badge == "dot" ? 0 : -5,
              child: Container(
                padding: EdgeInsets.all(badge == "dot" ? 4 : 6),
                constraints: BoxConstraints(
                  minWidth: badge == "dot" ? 8 : 16,
                  minHeight: badge == "dot" ? 8 : 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: badge == "dot" 
                    ? const SizedBox.shrink() 
                    : Text(
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