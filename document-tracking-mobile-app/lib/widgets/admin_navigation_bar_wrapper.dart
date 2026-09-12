import 'package:flutter/material.dart';

import '../utils/admin_notifications.dart';

import '../admin/admin_dashboard_page.dart';
import '../admin/admin_document_search_page.dart';
import '../admin/admin_settings_page.dart';

class AdminNavigationBarWrapper extends StatefulWidget {
  const AdminNavigationBarWrapper({super.key});

  @override
  State<AdminNavigationBarWrapper> createState() => _AdminNavigationBarWrapperState();
}

class _AdminNavigationBarWrapperState extends State<AdminNavigationBarWrapper> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    AdminNotificationUtils.syncAdminBadgeCounts();
    AdminNotificationUtils.initializeAdminListeners();

    _pages = [
      const AdminDashboardPage(),
      const AdminDocumentSearchPage(),
      const AdminAccSettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(1),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8BB839),
                Color(0xFF50AB7F),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF50AB7F).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.search_rounded, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF141414),
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Expanded(child: _buildNavItem(Icons.grid_view_rounded, 0, "Dashboard")),

              const SizedBox(width: 80), 

              Expanded(
                child: _buildAdminSettingsNavItem(
                  Icons.admin_panel_settings_rounded, 
                  2, 
                  "Admin Settings"
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.1 : 0.9,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
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
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSettingsNavItem(IconData icon, int index, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 0.9,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
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

            Positioned(
              right: 37,
              top: -4,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  adminPasswordRequestNotifier,
                  adminDeletionRequestNotifier,
                  adminQRReprintNotifier,
                  adminFacultyRequestNotifier,
                ]),
                builder: (context, _) {
                  final totalNotifications = adminPasswordRequestNotifier.value +
                      adminDeletionRequestNotifier.value +
                      adminQRReprintNotifier.value +
                      adminFacultyRequestNotifier.value;

                  if (totalNotifications == 0) return const SizedBox.shrink();

                  return Container(
                    padding: EdgeInsets.all(totalNotifications > 9 ? 4 : 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF141414), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16, 
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        totalNotifications > 9 ? '9+' : '$totalNotifications',
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}