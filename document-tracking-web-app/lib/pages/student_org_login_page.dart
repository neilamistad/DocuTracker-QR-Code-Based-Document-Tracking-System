import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../utils/password_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_background.dart';

import '../widgets/main_wrapper.dart';
import 'dummy_dashboard_page.dart';

class OrgLoginPage extends StatefulWidget {
  final String userType;
  const OrgLoginPage({super.key, required this.userType});

  @override
  State<OrgLoginPage> createState() => _OrgLoginPageState();
}

class _OrgLoginPageState extends State<OrgLoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isObscured = true;
  bool _isLoading = false;

  Future<void> login() async {
    if (_isLoading) return;

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

      if (org['email'] != email) {
        _showTopNotification("Invalid email", Colors.red);
        setState(() => _isLoading = false);
        return;
      }

      String storedHash = org['password_hash'];

      if (storedHash.length < 30 && !storedHash.startsWith('\$2a\$')) { 
        final hashed = hashPassword(storedHash);
        await supabase
          .from('student_org_accounts')
          .update({'password_hash': hashed})
          .ilike('email', email);
        storedHash = hashed;
      }

      if (verifyPassword(password, storedHash)) {
        if (!mounted) return;

        final bool isFirstTime = org['first_time_user'] ?? false;
        final String orgId = org['org_id'];

        try {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {

            final List<dynamic> rawTokens = org['fcm_token'] ?? [];
              
            List<String> updatedTokens = rawTokens.map((e) => e.toString()).toList();

            if (!updatedTokens.contains(fcmToken)) {
              updatedTokens.add(fcmToken);
              
              await supabase
                  .from('student_org_accounts')
                  .update({'fcm_token': updatedTokens})
                  .eq('org_id', orgId);
                  
              debugPrint("FCM Token synchronized for Org: $orgId");
            } else {
              debugPrint("FCM Token already exists for this Org device.");
            }
          }
        } catch (e) {
          debugPrint("Firebase Messaging Sync Error (Student Org): $e");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', orgId);
        await prefs.setString('userType', 'student org');
        await prefs.setBool('isFirstTime', isFirstTime);

        await supabase
          .from('password_requests')
          .update({'status': 'applied'})
          .eq('user_id', orgId)
          .eq('status', 'approved');

        if (!mounted) return;

        if (isFirstTime) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DummyDashboardPage(
                userType: "student org",
                userId: orgId,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainWrapper(
                userId: orgId,
                userType: "student org",
              ),
            ),
          );
        }
        return;
      } else {
        setState(() => _isLoading = false);
        _showTopNotification("Incorrect password", Colors.red);
        return;
      }

    } catch (e) {
      debugPrint("Login Error: $e");
      _showTopNotification("Connection error. Please try again.", Colors.red);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // REUSABLE REQUEST FUNCTION
  Future<void> handleForgotPasswordRequest({
    required String email,
    required String newPassword,
    required String confirmPassword,
    required Function(bool) setLoading,
  }) async {

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showTopNotification("All fields are required.", Colors.red);
      return;
    }
    if (newPassword != confirmPassword) {
      _showTopNotification("Passwords do not match.", Colors.red);
      return;
    }
    if (newPassword.length < 8) {
      _showTopNotification("Password must be at least 8 characters.", Colors.red);
      return;
    }

    setLoading(true);

    try {
      final existingUser = await supabase
          .from('student_org_accounts')
          .select('email, org_id')
          .eq('email', email.trim())
          .maybeSingle();

      if (existingUser == null) {
        _showTopNotification("No organization account found with that email.", Colors.red);
        setLoading(false);
        return;
      }

      final hashedPass = hashPassword(newPassword);
      final String orgId = existingUser['org_id'].toString();

      await supabase.from('password_requests').insert({
        'email_or_username': email.trim(),
        'new_password': hashedPass,
        'status': 'pending',
        'user_type': 'Student Org',
        'user_id': orgId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read_admin': false,
        'is_read_user': true,
      });

      if (!mounted) return;
      
      Navigator.pop(context);
      _showTopNotification("Request submitted! Please wait for admin approval.", Colors.green);

    } catch (e) {
      debugPrint("Request Error: $e");
      _showTopNotification("Connection error. Please try again.", Colors.red);
    } finally {
      if (mounted) setLoading(false); 
    }
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

  void showForgotPassword() {
    final emailForgotCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool isNewPassObscured = true;
    bool isConfirmPassObscured = true;
    bool isPopupLoading = false;

    final screenWidth = MediaQuery.of(context).size.width;

    final isDesktop = screenWidth > 500;

    showDialog(
      context: context,
      barrierDismissible: !isPopupLoading,
      builder: (_) => StatefulBuilder(
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight - 50 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF004D28), Color(0xFF78CF4E), Color(0xFF51AC80)],
                      ).createShader(Offset.zero & bounds.size),
                      child: Text(
                        'Forgot Password?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: isDesktop ? 28 : 24, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildPopupField(emailForgotCtrl, 'Enter your Org Email', onFocus: () => setPopupState((){})),
                    const SizedBox(height: 20),
                    _buildPopupField(
                      newPassCtrl, 
                      'New Password', 
                      isPass: true, 
                      obscured: isNewPassObscured,
                      onToggle: () => setPopupState(() => isNewPassObscured = !isNewPassObscured),
                      onFocus: () => setPopupState((){}),
                    ),
                    const SizedBox(height: 20),
                    _buildPopupField(
                      confirmPassCtrl, 
                      'Confirm Password', 
                      isPass: true, 
                      obscured: isConfirmPassObscured,
                      onToggle: () => setPopupState(() => isConfirmPassObscured = !isConfirmPassObscured),
                      onFocus: () => setPopupState((){}),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isPopupLoading ? null : () => Navigator.pop(context),
                            child: Text('Cancel', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: isDesktop ? 16 : 13)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: InkWell(
                            onTap: isPopupLoading ? null : () {
                              handleForgotPasswordRequest(
                                email: emailForgotCtrl.text.trim(),
                                newPassword: newPassCtrl.text.trim(),
                                confirmPassword: confirmPassCtrl.text.trim(),
                                setLoading: (val) => setPopupState(() => isPopupLoading = val),
                              );
                            },
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              height: 50,
                              decoration: ShapeDecoration(
                                gradient: isPopupLoading 
                                  ? const LinearGradient(colors: [Colors.grey, Colors.black26])
                                  : const LinearGradient(colors: [Color(0xFF34A24C), Color(0xFF004D28)]),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                              child: Center(
                                child: isPopupLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Container(
                    width: double.infinity, 
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 25 : 100,
                      vertical: 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNonStickyBackButton(isMobile),
                        const SizedBox(height: 30),
                        
                        isMobile
                          ? Column(
                              children: [
                                _buildWelcomeText(isMobile),
                                const SizedBox(height: 40),
                                _buildLoginCard(isMobile),
                              ],
                            )
                          : IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildWelcomeText(isMobile),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 80),
                                  Expanded(
                                    flex: 4, 
                                    child: _buildLoginCard(isMobile)
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNonStickyBackButton(bool isMobile) {
    return Transform.translate(
      offset: Offset(isMobile ? 0 : -60.0, 0), 
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: isMobile ? 20 : 22,
              ),
              const SizedBox(width: 8),
              Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment(-0.5, -0.86),
            end: Alignment(0.5, 0.86),
            colors: [Color(0xFF006A60), Color(0xFF92BC36), Color(0xFF004D28)],
            stops: [0.13, 0.54, 0.98],
            tileMode: TileMode.clamp,
          ).createShader(Offset.zero & bounds.size),
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              'Welcome Back',
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: isMobile ? 40 : 96,
                fontFamily: 'Noto Sans Hebrew',
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Please sign in to securely access your document tracking dashboard.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(color: Colors.white70, fontSize: isMobile ? 18 : 28, fontWeight: FontWeight.w200),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 30 : 50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 30 : 60),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(isMobile ? 30 : 50),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Student Organization', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: isMobile ? 28 : 38, fontWeight: FontWeight.w700)
              ),
              const SizedBox(height: 40),
              _buildField(emailCtrl, 'Org email', Symbols.mail, isMobile),
              const SizedBox(height: 20),
              _buildField(passCtrl, 'Enter password', Symbols.lock, isMobile, isPass: true),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showForgotPassword(), 
                  child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFE6AD3E))),
                ),
              ),
              const SizedBox(height: 10),
              _buildLoginButton(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, bool isMobile, {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass ? _isObscured : false,
        onSubmitted: (_) => login(),
        style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 18),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white30, fontSize: isMobile ? 12 : 16),
          prefixIcon: Icon(icon, color: const Color(0xFF51AC80), weight: 100),
          suffixIcon: isPass
              ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(_isObscured ? Symbols.visibility : Symbols.visibility_off,
                        color: Colors.white30, weight: 100, size: 22),
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 16 : 22),
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isMobile) {
    return InkWell(
      onTap: _isLoading ? null : login,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: isMobile ? 40 : 65,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B4338), Color(0xFF418948), Color(0xFF79D24E), Color(0xFF488F46), Color(0xFF0A473A)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Login', style: TextStyle(color: Colors.white, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ),
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
                  fontWeight: hasFocus ? FontWeight.w600 : FontWeight.w400,
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
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5)
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
              const SizedBox(height: 20),
            ],
          );
        }
      ),
    );
  }
}