import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '/widgets/background_wrapper.dart';
import '/widgets/user_navigation_bar_wrapper.dart';

import 'utils/password_hashing.dart';

import 'user/user_dummy_dashboard_page.dart';

final supabase = Supabase.instance.client;

class StudentOrgLoginPage extends StatefulWidget {
  const StudentOrgLoginPage({super.key});

  @override
  State<StudentOrgLoginPage> createState() => _StudentOrgLoginPageState();
}

class _StudentOrgLoginPageState extends State<StudentOrgLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // LOGIN LOGIC
  Future<void> login() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showTopNotification("Please enter your credentials", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final org = await supabase
          .from('student_org_accounts')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (org == null) {
        _showTopNotification("Invalid organization credentials", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      String storedHash = org['password_hash'];

      if (storedHash.length < 30 && !storedHash.startsWith('\$2a\$')) {
        if (storedHash == password) {
          final hashed = hashPassword(password);
          await supabase
              .from('student_org_accounts')
              .update({'password_hash': hashed})
              .eq('email', email);
          storedHash = hashed;
        } else {
          setState(() => _isLoading = false);
          _showTopNotification("Incorrect password", Colors.red);
          return;
        }
      }

      if (verifyPassword(password, storedHash)) {
        final bool isFirstTime = org['first_time_user'] ?? false;
        final String orgId = org['org_id'];

        await _handlePostLoginSync(
          userId: orgId,
          userType: 'student org',
          tableName: 'student_org_accounts',
          idColumn: 'org_id',
          rawTokens: org['fcm_token'],
          isFirstTime: isFirstTime,
        );

        await supabase
            .from('password_requests')
            .update({'status': 'applied'})
            .eq('user_id', orgId)
            .eq('status', 'approved');

        if (!mounted) return;
        setState(() => _isLoading = false);
        
        if (isFirstTime) {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => UserDummyDashboardPage(userType: "student org", userId: orgId)),
            (Route<dynamic> route) => false
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => UserNavigationBarWrapper(userId: orgId, userType: "student org")),
            (Route<dynamic> route) => false
          );
        }
      } else {
        setState(() => _isLoading = false);
        _showTopNotification("Incorrect password", Colors.red);
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      _showTopNotification("Connection error. Please try again.", Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostLoginSync({
    required String userId,
    required String userType,
    required String tableName,
    required String idColumn,
    required dynamic rawTokens,
    bool? isFirstTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('userType', userType);
    if (isFirstTime != null) await prefs.setBool('isUserFirstLogin', isFirstTime);

    try {
      String? currentDeviceToken = await FirebaseMessaging.instance.getToken();
      if (currentDeviceToken != null) {
        List<String> tokenList = [];
        if (rawTokens is List) {
          tokenList = List<String>.from(rawTokens.map((e) => e.toString()));
        }

        if (!tokenList.contains(currentDeviceToken)) {
          tokenList.add(currentDeviceToken);
          await supabase
              .from(tableName)
              .update({'fcm_token': tokenList})
              .eq(idColumn, userId);
          debugPrint("FCM Token synchronized for $userType: $userId");
        }
      }
    } catch (e) {
      debugPrint("Firebase Sync Error for $userType: $e");
    }
  }

  // FORGOT PASSWORD LOGIC
  Future<void> _handleForgotPassword(
    String email,
    String newPass,
    String confirmPass,
    Function(bool) setModalLoading,
    BuildContext modalContext,
  ) async {

    if (email.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showTopNotification("All fields are required.", Colors.red);
      return;
    }
    if (newPass != confirmPass) {
      _showTopNotification("Passwords do not match.", Colors.red);
      return;
    }
    if (newPass.length < 8) {
      _showTopNotification("Password must be at least 8 characters.", Colors.red);
      return;
    }

    setModalLoading(true);

    try {
      final existingUser = await supabase
          .from('student_org_accounts')
          .select('email, org_id')
          .eq('email', email.trim())
          .maybeSingle();

      if (existingUser == null) {
        _showTopNotification("No organization account found with that email.", Colors.red);
        setModalLoading(false);
        return;
      }

      final String orgId = existingUser['org_id'].toString();

      await supabase.from('password_requests').insert({
        'email_or_username': email.trim(),
        'new_password': hashPassword(newPass),
        'status': 'pending',
        'user_type': 'Student Org',
        'user_id': orgId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read_admin': false,
        'is_read_user': true,
      });

      if (!mounted) return;
      
      FocusManager.instance.primaryFocus?.unfocus();
      if (modalContext.mounted) Navigator.pop(modalContext);
      
      _showTopNotification("Request submitted! Please inform your Admin for approval.", Colors.green);

    } catch (e) {
      debugPrint("Forgot Pass Error: $e");
      _showTopNotification("Connection error. Please try again.", Colors.red);
    } finally {
      if (mounted) setModalLoading(false);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailResetCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    final TextEditingController confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool modalLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  "Enter your details below and wait for admin approval to change your password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _buildTextField(hint: 'Org Email', icon: Icons.email_outlined, controller: emailResetCtrl),
                  const SizedBox(height: 12),
                  _buildPopupTextField(
                    hint: 'New Password',
                    controller: newPassCtrl,
                    isObscured: obscureNew,
                    onToggle: () => setModalState(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 17),
                  _buildPopupTextField(
                    hint: 'Confirm New Password',
                    controller: confirmPassCtrl,
                    isObscured: obscureConfirm,
                    onToggle: () => setModalState(() => obscureConfirm = !obscureConfirm),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: modalLoading ? null : () {
                  FocusScope.of(context).unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                  Future.delayed(const Duration(milliseconds: 50), () => Navigator.pop(context));
                },
                child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6AD3E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: modalLoading ? null : () {
                  FocusScope.of(context).unfocus();
                  _handleForgotPassword(
                    emailResetCtrl.text, 
                    newPassCtrl.text, 
                    confirmPassCtrl.text, 
                    (val) => setModalState(() => modalLoading = val), 
                    context
                  );
                },
                child: modalLoading 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true, 
        body: SafeArea(
          bottom: false,
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF008174), 
                        Color(0xFF92BC36), 
                        Color(0xFF00984F)
                      ],
                    ).createShader(Offset.zero & bounds.size),
                    child: Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Noto Sans Hebrew',
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Please sign in to manage your organization\'s documents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            'Student Organization',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          _buildTextField(
                            hint: 'Organization Email',
                            icon: Icons.group_outlined,
                            controller: emailCtrl,
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            hint: 'Enter password',
                            icon: Icons.lock_outline,
                            controller: passCtrl,
                            isPassword: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: Color(0xFFE6AD3E), fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildLoginButton(screenWidth),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // WIDGETS
  Widget _buildTextField({required String hint, required IconData icon, required TextEditingController controller, bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(13)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white38, size: 20),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildPopupTextField({required String hint, required TextEditingController controller, required bool isObscured, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(13)),
      child: TextFormField(
        controller: controller,
        obscureText: isObscured,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          suffixIcon: IconButton(icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20), onPressed: onToggle),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildLoginButton(double screenWidth) {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B4338),
            Color(0xFF418948),
            Color(0xFF8BB839),
            Color(0xFF488F46),
            Color(0xFF0A473A)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : login,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}