import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../utils/admin_notification_utils.dart';
import '../utils/csv_export.dart';
import '../utils/pdf_export.dart';

import '../pages/user_type_page.dart';
import 'admin-settings-pages/admin_document_delete_requests_page.dart';
import 'admin-settings-pages/qr_reprint_requests_page.dart';
import 'admin-settings-pages/account_requests_page.dart';
import 'admin-settings-pages/password_requests_page.dart';
import 'admin-settings-pages/admin_help_guide_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final ScrollController _outerController = ScrollController();
  final ScrollController _cardScrollController = ScrollController();

  final supabase = Supabase.instance.client;

  late Future<String> _adminUsernameFuture;

  @override
  void initState() {
    super.initState();
    _adminUsernameFuture = _fetchAdminUsername();
  }

  Future<String> _fetchAdminUsername() async {
    try {
      final response = await Supabase.instance.client
          .from('admin_accounts')
          .select('username')
          .maybeSingle();

      if (response != null && response['username'] != null) {
        return response['username'].toString().toUpperCase();
      }
      return "ADMIN";
    } catch (e) {
      debugPrint("Error fetching username: $e");
      return "error";
    }
  }

  void handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Exit admin session?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
            onPressed: () async {
              try {
                final allChannels = Supabase.instance.client.getChannels();
                for (var ch in allChannels) {
                  await Supabase.instance.client.removeChannel(ch);
                }
                debugPrint("Admin Cleanup: All realtime channels removed.");
              } catch (e) {
                debugPrint("Admin Supabase Cleanup Error: $e");
              }

              AdminNotificationUtils.resetAdminNotificationUtils();

              final prefs = await SharedPreferences.getInstance();

              final String? adminId = prefs.getString('userId');

              FocusScope.of(context).unfocus();

              if (adminId != null) {
                try {

                  String? currentDeviceToken = await FirebaseMessaging.instance.getToken(
                    vapidKey: "BHZWBDkHQfKqbQg0VzzLZ-DE69fxgBInwDCtRfbqCP8-iTnD4VWnQII-qHqMZQRwve9yOB7cv1VoQG83C2vHjaM"
                  );

                  if (currentDeviceToken != null) {

                    final response = await Supabase.instance.client
                        .from('admin_accounts')
                        .select('fcm_token')
                        .eq('username', adminId)
                        .maybeSingle();

                    if (response != null && response['fcm_token'] != null) {

                      List<String> tokenList = List<String>.from(response['fcm_token']);
                      
                      if (tokenList.contains(currentDeviceToken)) {
                        tokenList.remove(currentDeviceToken);
                        await Supabase.instance.client
                            .from('admin_accounts')
                            .update({'fcm_token': tokenList})
                            .eq('username', adminId);
                        
                        debugPrint("Admin FCM Token for this device cleared successfully.");
                      }
                    }
                  }

                  await FirebaseMessaging.instance.deleteToken();


                } catch (dbError) {
                  debugPrint("Admin Database Token Cleanup Error: $dbError");
                }
              }

              await prefs.clear();

              await FirebaseMessaging.instance.deleteToken();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const UserTypePage()), 
                (route) => false
              );
            },
            child: const Text("Log out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExportPopup(BuildContext context) {
    String selectedOffice = 'All';
    DateTimeRange selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.12),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            title: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 15, bottom: 5),
                  child: const Text(
                    "Export Tracking History",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Positioned(
                  right: -5,
                  top: 0,
                  child: IconButton(
                    // Ripple effect circle
                    splashRadius: 20,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              // DITO NATIN LALAPARAN ANG POPUP
              width: 450, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _buildPopupDropdown(
                    label: "Filter by Office",
                    value: selectedOffice,
                    items: ['All', 'OCA', 'ODI', 'Department'],
                    onChanged: (val) => setPopupState(() => selectedOffice = val!),
                  ),
                  const SizedBox(height: 20),
                  _buildPopupActionTile(
                    label: "Selected Date Range",
                    subLabel: "${DateFormat('MMM dd').format(selectedDateRange.start)} - ${DateFormat('MMM dd, yyyy').format(selectedDateRange.end)}",
                    icon: Icons.date_range_rounded,
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF78CF4E),
                              onPrimary: Colors.black,
                              surface: Color(0xFF1E1E1E),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (range != null) setPopupState(() => selectedDateRange = range);
                    },
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await CsvExport.downloadTrackingHistory(
                            office: selectedOffice,
                            dateRange: selectedDateRange,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _showTopNotification("CSV Download Started!", Colors.green);
                        } catch (e) {
                          _showTopNotification("CSV Export failed: $e", Colors.red);
                        }
                      },
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text("CSV"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await PdfExport.downloadTrackingPdf(
                            office: selectedOffice,
                            dateRange: selectedDateRange,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _showTopNotification("PDF Generated Successfully!", Colors.green);
                        } catch (e) {
                          _showTopNotification("PDF Export failed: $e", Colors.red);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text("PDF"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF78CF4E),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopNotification(String msg, Color color) {
    if (!mounted) return;

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
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final bool isDesktop = availableWidth > 1000;

        return SingleChildScrollView(
          controller: _outerController,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 20,
              // 1. TANGGALIN ang vertical padding para hindi sumabog ang gap
              // Dahil may padding na ang wrapper mo.
              vertical: 20, 
            ),
            child: Column(
              children: [
                // 2. HEADER SECTION
                _buildHeaderSection(availableWidth),
                const SizedBox(height: 30),

                // 3. ADMIN CONTROLS CARD
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 800,
                      // Pinanatili ang 1000 logic mo dito
                      maxHeight: isDesktop ? 400 : 550, 
                    ),
                    child: _buildAdminCard(isDesktop),
                  ),
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(double screenWidth) {
    return Column(
      children: [
        Text(
          'Admin Settings',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 70 : 35,
            fontFamily: 'Noto Sans Hebrew',
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Manage system overall and approve requests',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16)
        ),
      ],
    );
  }

  Widget _buildAdminCard(bool isDesktop) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    Expanded( 
                      child: FutureBuilder<String>(
                        future: _adminUsernameFuture,
                        builder: (context, snapshot) {
                          final String displayUsername = snapshot.data ?? "ADMIN";

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              "$displayUsername CONTROLS",
                              style: TextStyle(
                                color: const Color(0xFF78CF4E),
                                fontSize: isDesktop ? 22 : 16,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: handleLogout,
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Scrollbar(
                  controller: _cardScrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _cardScrollController,
                    padding: EdgeInsets.zero,
                    children: _buildSettingItems(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSettingItems(BuildContext context) {
    return [

      ValueListenableBuilder<int>(
        valueListenable: adminQRReprintNotifier,
        builder: (context, count, _) => _adminSettingItem(
          icon: Icons.qr_code_2,
          title: "QR Requests Reprint",
          subtitle: "Approve document label reprints",
          badge: _buildCountBadge(count),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminQRReprintRequestsPage())),
        ),
      ),

      ValueListenableBuilder<int>(
        valueListenable: adminDeletionRequestNotifier,
        builder: (context, count, _) => _adminSettingItem(
          icon: Icons.delete_sweep,
          title: "Document Deletion Requests",
          subtitle: "Review and confirm file deletions",
          badge: _buildCountBadge(count),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDocumentDeleteRequestsPage())),
        ),
      ),

      ValueListenableBuilder<int>(
        valueListenable: adminFacultyRequestNotifier,
        builder: (context, count, _) => _adminSettingItem(
          icon: Icons.person_add_alt_1,
          title: "Account Requests",
          subtitle: "Approve new faculty registrations",
          badge: _buildCountBadge(count),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountRequestsPage())),
        ),
      ),

      ValueListenableBuilder<int>(
        valueListenable: adminPasswordRequestNotifier,
        builder: (context, count, _) => _adminSettingItem(
          icon: Icons.lock_reset,
          title: "Password Change Requests",
          subtitle: "Pending password resets",
          badge: _buildCountBadge(count),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordResetRequestsPage())),
        ),
      ),

      _adminSettingItem(
        icon: Icons.file_download_outlined,
        title: "Export Tracking History",
        subtitle: "Download history as CSV or PDF file",
        onTap: () => _showExportPopup(context),
      ),

      _adminSettingItem(
        icon: Icons.help_outline,
        title: "Help / Guide",
        subtitle: "System documentation",
        isLast: true,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHelpGuidePage())),
      ),
    ];
  }

  Widget _adminSettingItem({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap, 
    Widget? badge,
    bool isLast = false
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF78CF4E).withOpacity(0.1), 
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, color: const Color(0xFF78CF4E), size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
            ?badge, 
            const SizedBox(width: 15),
            const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();

    String displayCount = count > 99 ? "99+" : count.toString();

    return Container(
      constraints: const BoxConstraints(
        minWidth: 26, 
        minHeight: 26,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayCount,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Noto Sans Hebrew',
          ),
        ),
      ),
    );
  }

  Widget _buildPopupDropdown({
    required String label, 
    required String value, 
    required List<String> items, 
    required ValueChanged<String?> onChanged
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPopupActionTile({
    required String label, 
    required String subLabel, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF78CF4E), size: 24),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                Text(subLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _outerController.dispose();
    _cardScrollController.dispose();
    super.dispose();
  }
  
}