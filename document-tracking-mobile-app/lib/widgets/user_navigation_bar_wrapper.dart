import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../utils/user_notifications.dart';

import '../user/user_dashboard_page.dart';
import '../user/user_document_search_page.dart';
import '../user/user_account_settings_page.dart';
import '../user/user_document_registration_page.dart';
import '../user/user_tracking_history_page.dart';

class UserNavigationBarWrapper extends StatefulWidget {
  final String userId;
  final String userType;

  const UserNavigationBarWrapper({
    super.key, 
    required this.userId, 
    required this.userType
  });

  @override
  State<UserNavigationBarWrapper> createState() => _UserNavigationBarWrapper();
}

class _UserNavigationBarWrapper extends State<UserNavigationBarWrapper> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    UserNotificationUtils.syncInitialBadgeCounts(widget.userId);
    UserNotificationUtils.initializeListeners(widget.userId);

    _pages = [
      UserDashboardPage(userId: widget.userId, userType: widget.userType),
      UserDocumentSearchPage(userId: widget.userId, userType: widget.userType),
      UserDocumentRegistrationPage(userId: widget.userId, userType: widget.userType),
      UserDocumentTrackingHistoryPage(userId: widget.userId, userType: widget.userType),
      UserAccSettingsPage(userId: widget.userId, userType: widget.userType),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      backgroundColor: const Color(0xFF0D0D0D),
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // PREMIUM FAB WITH GLOW
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8BB839).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _onItemTapped(2),
          backgroundColor: const Color(0xFF8BB839),
          elevation: 0,
          shape: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8BB839),
                  const Color(0xFF6A8E2B),
                ],
              ),
            ),
            child: const Icon(Icons.add_rounded, size: 35, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 12.0,
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF141414),
        elevation: 0,
        child: Container(
          height: 65,
          decoration: BoxDecoration(
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(Icons.grid_view_rounded, 0, "Dashboard")),
              Expanded(child: _buildNavItem(Icons.search_rounded, 1, "Document Search")),
              const SizedBox(width: 70), 
              Expanded(child: _buildTrackingHistoryNavItem(Icons.location_pin, 3, "Tracking History", trackingBadgeNotifier)),
              Expanded(
                child: _buildAccountSettingsNavItem(
                  Icons.person_rounded, 
                  4, 
                  "Account Settings"
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60, 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.3 : 0.8,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center, 
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFF8BB839).withOpacity(0.15) 
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF8BB839) : Colors.white30,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingHistoryNavItem(IconData icon, int index, String label, ValueNotifier<int> notifier) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedIndex == 3) {
          markAllAsRead();
        } else {
          _onItemTapped(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (context, count, child) {
          return AnimatedScale(
            scale: isSelected ? 1.3 : 0.8,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8BB839).withOpacity(0.15) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xFF8BB839) : Colors.white30,
                    size: 26,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 8,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.all(count > 9 ? 4 : 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF141414), width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(count > 9 ? '+9' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountSettingsNavItem(IconData icon, int index, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<int>(
        valueListenable: deletionBadgeNotifier,
        builder: (context, deletionCount, _) {
          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: passwordRequestStatusNotifier,
            builder: (context, passData, _) {
              final String passStatus = passData?['status']?.toString().toLowerCase() ?? '';
              final bool isPassUnread = passData?['is_read_user'] == false;
              
              bool showRedDot = deletionCount > 0 || 
                              ((passStatus == 'approved' || passStatus == 'rejected') && isPassUnread);

              return AnimatedScale(
                scale: isSelected ? 1.3 : 0.8,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF8BB839).withOpacity(0.15) 
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? const Color(0xFF8BB839) : Colors.white30,
                        size: 26,
                      ),
                    ),
                    
                    // RED DOT BADGE
                    if (showRedDot)
                      Positioned(
                        right: 12,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF141414), width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}