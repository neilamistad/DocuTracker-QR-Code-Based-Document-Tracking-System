import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/background_wrapper.dart';
import '../utils/password_hashing.dart';
import '../utils/user_notifications.dart';

import 'user-settings/user_document_deletion_requests_page.dart';
import 'user-settings/user_help_guide_page.dart';
import '../usertype_page.dart';

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
    UserNotificationUtils.initializeListeners(widget.userId);
  }

  Future<void> fetchUserData() async {
    try {
      if (widget.userType.toLowerCase() == 'faculty') {
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
      UserNotificationUtils.resetAll(); 
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
          } else if (userType == 'student org') {
            tableName = 'student_org_accounts';
            idColumn = 'org_id';
          }

          String? currentDeviceToken = await FirebaseMessaging.instance.getToken();

          if (currentDeviceToken != null && tableName.isNotEmpty) {
            final response = await supabase
                .from(tableName)
                .select('fcm_token')
                .eq(idColumn, userId)
                .maybeSingle();

            if (response != null && response['fcm_token'] != null) {
              List<String> tokenList = List<String>.from(response['fcm_token']);

              if (tokenList.contains(currentDeviceToken)) {
                tokenList.remove(currentDeviceToken);

                await supabase
                    .from(tableName)
                    .update({'fcm_token': tokenList})
                    .eq(idColumn, userId);
                
                debugPrint("FCM Token removed for $userType: $userId");
              }
            }
          }

          await FirebaseMessaging.instance.deleteToken();
          
        } catch (e) {
          debugPrint("Cleanup Error during logout: $e");
        }
      }
    
      await prefs.clear();
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
          await supabase
              .from('password_requests')
              .update({'status': 'applied'})
              .eq('user_id', widget.userId)
              .eq('status', 'approved');
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
      title: "Update Password",
      content: "Your request is approved! You need to log out to use your new password.",
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

    // BASIC VALIDATIONS
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
    try {
      final approvedRequest = await supabase
          .from('password_requests')
          .select()
          .eq('user_id', widget.userId)
          .eq('status', 'approved')
          .maybeSingle();

      if (approvedRequest != null) {
        handleLogoutApprovedPassword();
        return;
      }

    } catch (e) {
      debugPrint("Error checking password status: $e");
    }

    await supabase
      .from('password_requests')
      .update({'status': 'applied'})
      .eq('user_id', widget.userId)
      .eq('status', 'rejected');
      
    _showActualPasswordForm(); 
  }

  // HELPER: SHOW TOP SNACKBAR
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

  void _showActualPasswordForm() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool isCurrentObscured = true;
    bool isNewObscured = true;
    bool isConfirmObscured = true;
    bool isPopupLoading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Change Password',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 25),
                    
                    _buildModernField(
                      controller: currentPassCtrl, 
                      label: 'Current Password', 
                      isObscured: isCurrentObscured,
                      onToggle: () => setPopupState(() => isCurrentObscured = !isCurrentObscured),
                    ),
                    const SizedBox(height: 15),
                    _buildModernField(
                      controller: newPassCtrl, 
                      label: 'New Password', 
                      isObscured: isNewObscured,
                      onToggle: () => setPopupState(() => isNewObscured = !isNewObscured),
                    ),
                    const SizedBox(height: 15),
                    _buildModernField(
                      controller: confirmPassCtrl, 
                      label: 'Confirm New Password', 
                      isObscured: isConfirmObscured,
                      onToggle: () => setPopupState(() => isConfirmObscured = !isConfirmObscured),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isPopupLoading ? null : () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isPopupLoading ? null : () async {
                              FocusScope.of(context).unfocus();
                              await handlePasswordChangeRequest(
                                currentPass: currentPassCtrl.text.trim(),
                                newPass: newPassCtrl.text.trim(),
                                confirmPass: confirmPassCtrl.text.trim(),
                                setLoading: (val) => setPopupState(() => isPopupLoading = val),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BB839),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: isPopupLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Request Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      context, MaterialPageRoute(builder: (_) => const UserTypePage()), (route) => false);
  }

  void _showLogoutDialog({required String title, required String content, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Log out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(25, 50, 25, 50),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Account Settings',
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
                  'Monitor the real-time location and transfer history of your files between offices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 40),

                _buildGlassContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF50AB7F),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isDataLoading)
                                    const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF50AB7F))
                                    )
                                  else
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Color(0xFF50AB7F), 
                                          fontSize: 17, 
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  const SizedBox(height: 4),

                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      'ID: $displayId',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5), 
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildLogoutButton(onTap: handleLogout),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<Map<String, dynamic>?>(
                        valueListenable: passwordRequestStatusNotifier,
                        builder: (context, data, _) {
                          final String status = data?['status']?.toString().toLowerCase() ?? '';
                          final bool isRead = data?['is_read_user'] ?? true;

                          Widget? currentBadge;
                          if (!isRead && (status == 'approved' || status == 'rejected')) {
                            currentBadge = _buildStatusBadge(status);
                          }

                          return _buildSettingItem(
                            'Password Change Request',
                            icon: Icons.lock_reset_rounded,
                            onTap: () {
                              showPasswordChangePopup();
                            },
                            customBadge: currentBadge,
                          );
                        },
                      ),

                      _buildThinDivider(),

                      ValueListenableBuilder<int>(
                        valueListenable: deletionBadgeNotifier,
                        builder: (context, count, child) {
                          return _buildSettingItem(
                            'Document Deletion Requests',
                            icon: Icons.delete_rounded,
                            badgeCount: count, 
                            onTap: () {

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDocumentDeletionRequestsPage(
                                    userId: widget.userId,
                                    userType: widget.userType,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      _buildThinDivider(),

                      _buildSettingItem('Help / Guide',
                      icon: Icons.help_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserHelpPage(
                                userId: widget.userId,
                                userType: widget.userType,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // UI HELPER WIDGETS (Glassmorphism Style)
  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    String title, {
    required VoidCallback onTap,
    required IconData icon,
    Widget? customBadge,
    int? badgeCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.05),
        highlightColor: Colors.white.withOpacity(0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(
                icon, 
                color: const Color(0xFF8BB839), 
                size: 22
              ),
              const SizedBox(width: 15),
              
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              if (customBadge != null)
                Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: customBadge,
                )
              else if (badgeCount != null && badgeCount > 0)
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
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0B4338),
              Color(0xFF418948),
              Color(0xCC8BB839),
              Color(0xFF488F46),
              Color(0xFF0A473A)
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Text(
          'Log out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF50AB7F))),
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white24, size: 20),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isApproved = status.toLowerCase() == 'approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFF2ECC71) : Color(0xFFE74C3C),
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
}