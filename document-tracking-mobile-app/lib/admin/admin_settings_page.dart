import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/background_wrapper.dart';

import '../utils/admin_notifications.dart';
import '../utils/csv_export.dart';
import '../utils/pdf_export.dart';

import '../usertype_page.dart';

import 'admin-settings/qr_reprint_requests_page.dart';
import 'admin-settings/admin_document_deletion_requests_page.dart';
import 'admin-settings/account_requests_page.dart';
import 'admin-settings/password_change_requests_page.dart';
import 'admin-settings/admin_help_guide_page.dart';

class AdminAccSettingsPage extends StatefulWidget {

  const AdminAccSettingsPage({
    super.key,
  });

  @override
  State<AdminAccSettingsPage> createState() => _AdminAccSettingsPageState();
}

class _AdminAccSettingsPageState extends State<AdminAccSettingsPage> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _getAdminName();
  }
  
  String adminName = "Loading...";

  Future<void> _getAdminName() async {
    try {
      final data = await supabase
          .from('admin_accounts')
          .select('username')
          .limit(1)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          adminName = data['username'].toString().toUpperCase();
        });
      }
    } catch (e) {
      debugPrint("Error fetching admin name: $e");
      if (mounted) setState(() => adminName = "error");
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
                  String? currentDeviceToken = await FirebaseMessaging.instance.getToken();

                  if (currentDeviceToken != null) {
                    final data = await Supabase.instance.client
                        .from('admin_accounts')
                        .select('fcm_token')
                        .eq('username', adminId)
                        .maybeSingle();

                    if (data != null && data['fcm_token'] != null) {
                      List<String> tokenList = List<String>.from(data['fcm_token']);

                      if (tokenList.contains(currentDeviceToken)) {
                        tokenList.remove(currentDeviceToken);

                        await Supabase.instance.client
                            .from('admin_accounts')
                            .update({'fcm_token': tokenList})
                            .eq('username', adminId);
                            
                        debugPrint("Admin FCM Token for this device cleared.");
                      }
                    }
                  }

                  await FirebaseMessaging.instance.deleteToken();
                  
                } catch (dbError) {
                  debugPrint("Admin Database Token Cleanup Error: $dbError");
                }
              }

              await prefs.clear();

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

  void _showExportPopup() {
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
            backgroundColor: const Color(0xFF1A1A1A),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10),
                  child: const Text(
                    "Export History",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  right: -10,
                  top: -10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400, // Pinalapad ang popup
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Office Dropdown
                  _buildPopupDropdown(
                    label: "Category",
                    value: selectedOffice,
                    items: ['All', 'OCA', 'ODI', 'Department'],
                    onChanged: (val) => setPopupState(() => selectedOffice = val!),
                  ),
                  const SizedBox(height: 20),
                  // Date Picker Tile
                  _buildPopupActionTile(
                    label: "Date Range",
                    subLabel: "${DateFormat('MMM dd').format(selectedDateRange.start)} - ${DateFormat('MMM dd, yyyy').format(selectedDateRange.end)}",
                    icon: Icons.date_range_rounded,
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF8BB839),
                              onPrimary: Colors.white,
                              surface: Color(0xFF1A1A1A),
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
            actionsPadding: const EdgeInsets.fromLTRB(30, 0, 30, 20),
            actions: [
              Column(
                children: [
                  // PDF EXPORT BUTTON (Primary Action)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BB839),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        try {
                          // Optional: Show loading indicator
                          await PdfExport.downloadTrackingPdf(
                            office: selectedOffice == 'All' ? 'All' : selectedOffice,
                            dateRange: selectedDateRange,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          debugPrint("PDF Export Error: $e");
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: const Text("Export as PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // CSV EXPORT BUTTON (Secondary Action)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () async {
                        try {
                          await CsvExport.downloadTrackingHistory(
                            office: selectedOffice == 'All offices' ? 'All' : selectedOffice,
                            dateRange: selectedDateRange,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          debugPrint("CSV Export Error: $e");
                        }
                      },
                      icon: const Icon(Icons.table_chart, size: 20),
                      label: const Text("Export as CSV"),
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

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(25, 50, 25, 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Admin Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'System Management and Request Oversight',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 40),

                _buildGlassContainer(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF50AB7F),
                              child: Icon(Symbols.admin_panel_settings_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      adminName,
                                      style: TextStyle(
                                        color: adminName == "Loading..." 
                                            ? const Color(0xFF50AB7F).withOpacity(0.3) 
                                            : const Color(0xFF50AB7F),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            _buildLogoutButton(onTap: handleLogout),
                          ],
                        ),
                      ),

                      ValueListenableBuilder<int>(
                        valueListenable: adminQRReprintNotifier,
                        builder: (context, count, _) {
                          return _buildSettingItemWithCountBadge(
                            'QR Reprint Requests',
                            count,
                            icon: Icons.qr_code_scanner_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const QRReprintRequestsPage()),
                              );
                            },
                          );
                        },
                      ),
                      _buildThinDivider(),

                      ValueListenableBuilder<int>(
                        valueListenable: adminDeletionRequestNotifier,
                        builder: (context, count, _) {
                          return _buildSettingItemWithCountBadge(
                            'Document Deletion Requests',
                            count,
                            icon: Icons.delete_sweep_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AdminDocumentDeleteRequestsPage()),
                              );
                            },
                          );
                        },
                      ),
                      _buildThinDivider(),

                      ValueListenableBuilder<int>(
                        valueListenable: adminFacultyRequestNotifier,
                        builder: (context, count, _) {
                          return _buildSettingItemWithCountBadge(
                            'Account Requests',
                            count,
                            icon: Icons.person_add_alt_1_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AccountRequestsPage()),
                              );
                            },
                          );
                        },
                      ),
                      _buildThinDivider(),

                      ValueListenableBuilder<int>(
                        valueListenable: adminPasswordRequestNotifier,
                        builder: (context, count, _) {
                          return _buildSettingItemWithCountBadge(
                            'Password Change Requests',
                            count,
                            icon: Icons.lock_reset_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PasswordResetRequestsPage(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _buildThinDivider(),

                      _buildSettingItem(
                        'Export Tracking History',
                        icon: Icons.file_download_rounded,
                        onTap: _showExportPopup,
                      ),

                      _buildThinDivider(),

                      _buildSettingItem(
                        'Help / Guide',
                        icon: Icons.help_outline_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminHelpPage()),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                const Text(
                  "CvSU Document Tracking System v1.0",
                  style: TextStyle(color: Colors.white12, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI HELPERS

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingItem(String title, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8BB839), size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItemWithCountBadge(String title, int? badgeCount, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8BB839), size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 20, left: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeCount > 9 ? "9+" : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // CSV Download Popup Widgets
  Widget _buildPopupDropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPopupActionTile({required String label, required String subLabel, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF8BB839)),
      title: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      subtitle: Text(subLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  Widget _buildThinDivider() {
    return Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 24, endIndent: 24);
  }

  Widget _buildLogoutButton({required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
      tooltip: "Logout",
    );
  }
}