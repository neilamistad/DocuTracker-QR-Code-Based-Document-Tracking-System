import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../utils/password_utils.dart';
import '../utils/notification_utils.dart';

import 'user-settings-pages/document_deletion_requests_page.dart';
import 'user-settings-pages/help_guide_page.dart';
import '../pages/user_type_page.dart';

class UserAccSettingsPage extends StatefulWidget {
  final String userType;
  final String userId;

  const UserAccSettingsPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<UserAccSettingsPage> createState() => _UserAccSettingsPageState();
}

class _UserAccSettingsPageState extends State<UserAccSettingsPage> {
  final supabase = Supabase.instance.client;
  
  String displayName = "Loading...";
  String displayId = "Loading...";
  bool isDataLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();

    NotificationUtils.initializeListeners(widget.userId);
  }

  Future<void> fetchUserData() async {
    try {
      if (widget.userType.toLowerCase() == 'faculty') {
        // GET THE first_name, last_name, faculty_id
        final data = await supabase
            .from('faculty_accounts')
            .select('first_name, last_name, faculty_id')
            .eq('faculty_id', widget.userId)
            .single();

        setState(() {
          displayName = "${data['first_name']} ${data['last_name']}".toUpperCase();
          displayId = data['faculty_id'].toString();
          isDataLoading = false;
        });
      } else if (widget.userType.toLowerCase() == 'student org') {
        // GET THE org_name, org_id
        final data = await supabase
            .from('student_org_accounts')
            .select('org_name, org_id')
            .eq('org_id', widget.userId)
            .single();

        setState(() {
          displayName = data['org_name'].toString().toUpperCase();
          displayId = data['org_id'].toString();
          isDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      setState(() {
        displayName = "USER NOT FOUND";
        displayId = widget.userId;
        isDataLoading = false;
      });
    }
  }

  Future<void> _processLogoutCleanUp() async {
    try {
      NotificationUtils.resetAll(); 

      final channels = supabase.getChannels();
      for (var channel in channels) {
        await supabase.removeChannel(channel);
      }

      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');
      final String? userType = prefs.getString('userType');

      FocusScope.of(context).unfocus();

      if (userId != null && userType != null) {
        try {
          String tableName = '';
          String idColumn = '';

          if (userType == 'faculty') {
            tableName = 'faculty_accounts';
            idColumn = 'faculty_id';
          } else {
            tableName = 'student_org_accounts';
            idColumn = 'org_id';
          }

          String? currentDeviceToken = await FirebaseMessaging.instance.getToken();

          if (currentDeviceToken != null) {

            final data = await supabase
                .from(tableName)
                .select('fcm_token')
                .eq(idColumn, userId)
                .single();

            List<String> tokenList = List<String>.from(data['fcm_token'] ?? []);

            tokenList.removeWhere((token) => token == currentDeviceToken);

            await supabase
                .from(tableName)
                .update({'fcm_token': tokenList})
                .eq(idColumn, userId);
            
            debugPrint("FCM Token for THIS device removed from $userType ($userId).");
          }

          await FirebaseMessaging.instance.deleteToken();

        } catch (dbError) {
          debugPrint("Database token cleanup error: $dbError");
        }
      }
      
      await prefs.clear();
      
      debugPrint("Logout Clean-up: All listeners and sessions cleared.");
    } catch (e) {
      debugPrint("Error during logout cleanup: $e");
    }
  }

  Future<void> handleLogout() async {
    _showLogoutDialog(
      title: "Log out",
      content: "Are you sure you want to log out?",
      onConfirm: () async {
        try {
          final checkRequest = await supabase
              .from('password_requests')
              .select()
              .eq('user_id', widget.userId)
              .eq('status', 'approved')
              .maybeSingle();

          if (checkRequest != null) {
            debugPrint("Approved password request found. Updating to applied...");
            await supabase
                .from('password_requests')
                .update({'status': 'applied'})
                .eq('user_id', widget.userId)
                .eq('status', 'approved');
          }
        } catch (e) {
          debugPrint("Error updating password status during logout: $e");
        }

        await _processLogoutCleanUp();
        _navigateToLogin();
      },
    );
  }

  Future<void> handleLogoutApprovedPassword() async {
    _showLogoutDialog(
      title: "Log out",
      content: "You need to log out if you want to try your new password",
      onConfirm: () async {
        try {
          await supabase
              .from('password_requests')
              .update({'status': 'applied'})
              .eq('user_id', widget.userId)
              .eq('status', 'approved');
        } catch (e) {
          debugPrint("Error updating password status: $e");
        }
        
        await _processLogoutCleanUp();
        _navigateToLogin();
      },
    );
  }

  Future<void> handlePasswordChangeRequest({
    required String currentPass,
    required String newPass,
    required String confirmPass,
    required Function(bool) setLoading,
  }) async {

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showTopNotification("All fields are required.", Colors.red);
      return;
    }
    if (newPass != confirmPass) {
      _showTopNotification("New passwords do not match.", Colors.red);
      return;
    }
    if (newPass.length < 8) {
      _showTopNotification("New password must be at least 8 characters.", Colors.red);
      return;
    }

    setLoading(true);

    try {
      final isFaculty = widget.userType.toLowerCase() == 'faculty';
      final table = isFaculty ? 'faculty_accounts' : 'student_org_accounts';
      final idCol = isFaculty ? 'faculty_id' : 'org_id';
      final emailCol = isFaculty ? 'cvsu_email' : 'email';

      final userData = await supabase
          .from(table)
          .select('password_hash, $emailCol')
          .eq(idCol, widget.userId)
          .single();

      final storedHash = userData['password_hash'];
      final userEmail = userData[emailCol];

      if (!verifyPassword(currentPass, storedHash)) {
        _showTopNotification("Incorrect current password.", Colors.red);
        setLoading(false);
        return;
      }

      final hashedNewPass = hashPassword(newPass);

      await supabase.from('password_requests').insert({
        'email_or_username': userEmail,
        'new_password': hashedNewPass,
        'status': 'pending',
        'user_type': widget.userType,
        'user_id': widget.userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      
      Navigator.pop(context);
      _showTopNotification("Change request submitted! Waiting for admin approval.", Colors.green);

    } catch (e) {
      debugPrint("Password Change Error: $e");
      _showTopNotification("Something went wrong. Please try again.", Colors.red);
    } finally {
      if (mounted) setLoading(false);
    }
  }


  Future<void> showPasswordChangePopup() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool isCurrentObscured = true;
    bool isNewObscured = true;
    bool isConfirmObscured = true;

    bool isPopupLoading = false;

    final screenWidth = MediaQuery.of(context).size.width;

    final isDesktop = screenWidth > 500;

    try {
      await supabase
        .from('password_requests')
        .update({'status': 'applied'})
        .eq('user_id', widget.userId)
        .eq('status', 'rejected');

    } catch (e) {
      debugPrint("Error updating password status: $e");
    }

    showDialog(
      context: context,
      barrierDismissible: !isPopupLoading,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: isDesktop ? 420 : screenWidth * 0.9,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight - 50 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFF004D28), Color(0xFF78CF4E), Color(0xFF51AC80)],
                        stops: [0.06, 0.50, 0.85],
                      ).createShader(Offset.zero & bounds.size),
                      child: Text(
                        'Change Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 28 : 24,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildPopupField(
                      currentPassCtrl, 
                      'Current Password', 
                      isPass: true, 
                      obscured: isCurrentObscured,
                      onToggle: () => setPopupState(() => isCurrentObscured = !isCurrentObscured),
                      onFocus: () => setPopupState(() {}),
                    ),
                    const SizedBox(height: 20),

                    _buildPopupField(
                      newPassCtrl, 
                      'New Password', 
                      isPass: true, 
                      obscured: isNewObscured,
                      onToggle: () => setPopupState(() => isNewObscured = !isNewObscured),
                      onFocus: () => setPopupState(() {}),
                    ),
                    const SizedBox(height: 20),

                    _buildPopupField(
                      confirmPassCtrl, 
                      'Confirm New Password', 
                      isPass: true, 
                      obscured: isConfirmObscured,
                      onToggle: () => setPopupState(() => isConfirmObscured = !isConfirmObscured),
                      onFocus: () => setPopupState(() {}),
                    ),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isPopupLoading ? null : () => Navigator.pop(context),
                            child: Text('Cancel', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: isDesktop ? 16 : 13))
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: InkWell(
                            onTap: isPopupLoading ? null : () async {
                              await handlePasswordChangeRequest(
                                currentPass: currentPassCtrl.text.trim(),
                                newPass: newPassCtrl.text.trim(),
                                confirmPass: confirmPassCtrl.text.trim(),
                                setLoading: (val) => setPopupState(() => isPopupLoading = val),
                              );
                            },
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              height: 50,
                              decoration: ShapeDecoration(
                                gradient: isPopupLoading 
                                  ? const LinearGradient(colors: [Colors.grey, Colors.black26])
                                  : const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [Color(0xFF34A24C), Color(0xFF004D28)],
                                    ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                              child: Center(
                                child: isPopupLoading
                                    ? const SizedBox(
                                        height: 20, 
                                        width: 20, 
                                        child: CircularProgressIndicator(
                                          color: Colors.white, 
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text('Request Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isDesktop ? 16 : 13)),
                              ),
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
        },
      ),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => const UserTypePage()), 
      (route) => false
    );
  }

  void _showLogoutDialog({
    required String title, 
    required String content, 
    required VoidCallback onConfirm
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            child: const Text("Log out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // REUSABLE SNACKBAR
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

  // UI PART

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: isDesktop ? 100 : 25, 
              right: isDesktop ? 100 : 25, 
              top: 40, 
              bottom: 20
            ),
            child: Column(
              children: [
                Text(
                  'Account Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 75 : 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage your profile security and requests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70, 
                    fontSize: isDesktop ? 16 : 14, 
                    fontWeight: FontWeight.w200
                  ),
                ),
              ],
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 100 : 20, 
                  vertical: 10
                ),
                child: _buildAccountCard(isDesktop),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isApproved = status.toLowerCase() == 'approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAccountCard(bool isDesktop) {
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(35),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isDataLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF50AB7F)))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    color: const Color(0xFF50AB7F), 
                                    fontSize: isDesktop ? 26 : 18, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          Text(
                            'ID: $displayId',
                            style: TextStyle(color: Colors.white60, fontSize: isDesktop ? 16 : 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isDesktop ? 0 : 10),
                    _logoutButton(),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // PASSWORD CHANGE
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: passwordRequestStatusNotifier,
                      builder: (context, data, child) {
                        final String? status = data?['status']?.toString().toLowerCase();
                        bool isApproved = status == 'approved';

                        final dynamic rawIsRead = data?['is_read_user'];
                        final bool isUnread = (rawIsRead == false || rawIsRead == 0 || rawIsRead == "false");

                        Widget? statusBadge;
                        if (isUnread && status != null && status != 'pending' && status != 'applied' && status != 'null') {
                          statusBadge = _buildStatusBadge(status);
                        }

                        return _settingItem(
                          "Password Change",
                          "Update your account security credentials",
                          Icons.lock_outline_rounded,
                          customBadge: statusBadge,
                          onTap: () => isApproved ? handleLogoutApprovedPassword() : showPasswordChangePopup(),
                        );
                      },
                    ),

                    // DOCUMENT DELETION
                    ValueListenableBuilder<int>(
                      valueListenable: deletionBadgeNotifier,
                      builder: (context, count, child) {
                        return _settingItem(
                          "Document Deletion Requests",
                          "View and manage your pending removal requests",
                          Icons.delete_sweep_outlined,
                          badgeCount: count > 0 ? count : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentDeletionRequestsPage(
                                  userId: widget.userId,
                                  userType: widget.userType,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // HELP / GUIDE
                    _settingItem(
                      "Help / Guide",
                      "Learn how to use the tracking system effectively",
                      Icons.help_outline_rounded,
                      isLast: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserHelpPage(
                            userId: widget.userId,
                            userType: widget.userType,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingItem(
    String title, 
    String subtitle, 
    IconData icon, {
    bool isLast = false, 
    int? badgeCount, 
    Widget? customBadge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF78CF4E), size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w300),
                  ),
                ],
              ),
            ),
            
            if (customBadge != null) 
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: customBadge,
              )
            else if (badgeCount != null && badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 15),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount > 9 ? "9+" : badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return InkWell(
      onTap: handleLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B4338), Color(0xFF418948), Color(0xFF8BB839)]),
          borderRadius: BorderRadius.circular(2300),
        ),
        child: const Text('Log out', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400)),
      ),
    );
  }

  Widget _buildPopupField(
    TextEditingController ctrl, 
    String hint, {
    bool isPass = false, 
    bool obscured = false, 
    VoidCallback? onToggle,
    VoidCallback? onFocus,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (onFocus != null) onFocus();
      },
      child: Builder(
        builder: (context) {
          final bool hasFocus = Focus.of(context).hasFocus;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint, 
                style: TextStyle(
                  color: hasFocus ? const Color(0xFF78CF4E) : Colors.white60, 
                  fontSize: 14, 
                  fontWeight: hasFocus ? FontWeight.bold : FontWeight.w400,
                )
              ),
              TextField(
                controller: ctrl,
                obscureText: isPass ? obscured : false,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: const Color(0xFF78CF4E),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.2)
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF78CF4E), width: 2)
                  ),
                  suffixIcon: isPass 
                    ? IconButton(
                        icon: Icon(
                          obscured ? Icons.visibility_off : Icons.visibility, 
                          color: hasFocus ? const Color(0xFF78CF4E) : Colors.white38, 
                          size: 20
                        ),
                        onPressed: onToggle,
                      )
                    : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}