import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '/widgets/background_wrapper.dart';
import '/widgets/user_navigation_bar_wrapper.dart';
import '/widgets/admin_navigation_bar_wrapper.dart';

import 'utils/password_hashing.dart';

import 'faculty_registration_page.dart';
import '/user/user_dummy_dashboard_page.dart';

final supabase = Supabase.instance.client;

class FacultyLoginPage extends StatefulWidget {
  const FacultyLoginPage({super.key});

  @override
  State<FacultyLoginPage> createState() => _FacultyLoginPageState();
}

class _FacultyLoginPageState extends State<FacultyLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController identifierCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // LOGIN LOGIC
  Future<void> login() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final identifier = identifierCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showTopNotification("Please fill in all fields", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. RUN QUERIES IN PARALLEL
      final results = await Future.wait([
        supabase.from('admin_accounts').select().eq('username', identifier).maybeSingle(),
        supabase.from('faculty_accounts')
            .select()
            .or('cvsu_email.eq.$identifier,faculty_id.eq.$identifier')
            .maybeSingle(),
      ]);

      final admin = results[0];
      final faculty = results[1];

      // ADMIN LOGIC
      if (admin != null) {
        String storedHash = admin['password_hash'];
        final String username = admin['username'];

        if (storedHash.length < 30 && !storedHash.startsWith('\$2a\$')) {
          if (storedHash == password) {
            final hashed = hashPassword(password);
            await supabase.from('admin_accounts').update({'password_hash': hashed}).eq('username', username);
            storedHash = hashed;
          } else {
            _stopLoadingAndShowError("Invalid credentials");
            return;
          }
        }

        if (verifyPassword(password, storedHash)) {
          await _handlePostLoginSync(
            userId: username, 
            userType: 'admin', 
            tableName: 'admin_accounts', 
            idColumn: 'username',
            rawTokens: admin['fcm_token']
          );

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (_) => AdminNavigationBarWrapper()),
            (Route<dynamic> route) => false
          );
          return;
        }
      }

      // FACULTY LOGIC
      if (faculty != null) {
        final String storedHash = faculty['password_hash'];

        if (verifyPassword(password, storedHash)) {
          final String facultyId = faculty['faculty_id'];
          final bool isFirstTime = faculty['first_time_user'] ?? false;


          await _handlePostLoginSync(
            userId: facultyId,
            userType: 'faculty',
            tableName: 'faculty_accounts',
            idColumn: 'faculty_id',
            rawTokens: faculty['fcm_token'],
            isFirstTime: isFirstTime
          );

          await supabase
              .from('password_requests')
              .update({'status': 'applied'})
              .eq('user_id', facultyId)
              .eq('status', 'approved');

          if (!mounted) return;
          setState(() => _isLoading = false);

          if (isFirstTime) {
            Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (_) => UserDummyDashboardPage(userType: "faculty", userId: facultyId)),
              (Route<dynamic> route) => false
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (_) => UserNavigationBarWrapper(userId: facultyId, userType: "faculty")),
              (Route<dynamic> route) => false
            );
          }
          return;
        } else {
          _stopLoadingAndShowError("Incorrect password");
          return;
        }
      }

      _stopLoadingAndShowError("Account not found or not approved");

    } catch (e) {
      debugPrint("Login Error: $e");
      _stopLoadingAndShowError("An unexpected error occurred");
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

  Future<void> _handleForgotPassword(
    String email, 
    String newPass, 
    String confirmPass, 
    Function(bool) setModalLoading, 
    BuildContext modalContext
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    FocusScope.of(context).unfocus();

    if (cleanEmail.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
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
          .from('faculty_accounts')
          .select('cvsu_email, faculty_id')
          .eq('cvsu_email', cleanEmail)
          .maybeSingle();

      if (existingUser == null) {
        _showTopNotification("No faculty account found with that email.", Colors.red);
        setModalLoading(false);
        return;
      }

      final String facultyId= existingUser['faculty_id'].toString();

      await supabase.from('password_requests').insert({
        'email_or_username': cleanEmail,
        'new_password': hashPassword(newPass),
        'status': 'pending',
        'user_type': 'faculty',
        'user_id' : facultyId,
        'created_at': DateTime.now().toIso8601String(),
        'is_read_admin': false,
        'is_read_user': true,
      });

      if (!mounted) return;
      
      Navigator.pop(modalContext);

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
    final TextEditingController newPasswordCtrl = TextEditingController();
    final TextEditingController confirmPasswordCtrl = TextEditingController();
    
    
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
                const Text(
                  "Reset Password",
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your details below and wait for admin approval to change your password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60, 
                    fontSize: 12, 
                    fontWeight: FontWeight.w400
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _buildTextField(
                    hint: 'CVSU Email', 
                    icon: Icons.email_outlined, 
                    controller: emailResetCtrl
                  ),

                  const SizedBox(height: 12),
                  _buildPopupTextField(
                    hint: 'New Password',
                    controller: newPasswordCtrl,
                    isObscured: obscureNew,
                    onToggle: () {
                      setModalState(() => obscureNew = !obscureNew);
                    },
                  ),

                  const SizedBox(height: 12),
                  _buildPopupTextField(
                    hint: 'Confirm New Password',
                    controller: confirmPasswordCtrl,
                    isObscured: obscureConfirm,
                    onToggle: () {
                      setModalState(() => obscureConfirm = !obscureConfirm);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: modalLoading ? null : () {
                  FocusScope.of(context).unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                  
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) Navigator.pop(context);
                  });
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
                    newPasswordCtrl.text, 
                    confirmPasswordCtrl.text, 
                    (val) => setModalState(() => modalLoading = val), 
                    context
                  );
                }, 
                child: modalLoading 
                  ? const SizedBox(
                      width: 18, 
                      height: 18, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // HELPER: STOP LOADING AND SHOW ERROR
  void _stopLoadingAndShowError(String error) {
    setState(() => _isLoading = false);
    _showTopNotification(error, Colors.red);
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
        body: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.08,
              vertical: 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment(-0.5, -0.86),
                    end: Alignment(0.5, 0.86),
                    colors: [
                      Color(0xFF008174), 
                      Color(0xFF92BC36), 
                      Color(0xFF00984F)
                    ],
                    stops: [0.13, 0.54, 0.98],
                    tileMode: TileMode.clamp,
                  ).createShader(Offset.zero & bounds.size),
                  child: Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.12,
                      fontFamily: 'Noto Sans Hebrew',
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Please sign in to securely access your document tracking dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.w400,
                  ),
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
                          'Faculty',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildTextField(
                          hint: 'CVSU Email or Faculty ID',
                          icon: Icons.person_outline,
                          controller: identifierCtrl,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          hint: 'Enter password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          controller: passCtrl,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFFE6AD3E),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildLoginButton(screenWidth),
                        const SizedBox(height: 25),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FacultyRegistrationPage(),
                              ),
                            );
                          },
                          child: const Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: "Register here",
                                  style: TextStyle(
                                    color: Color(0xFF8BB839),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // REUSABLE TEXT FIELD
  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    VoidCallback? onToggleVisible,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xCCD9D9D9), fontSize: 12, fontWeight: FontWeight.w300),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () {
                    if (onToggleVisible != null) {
                      onToggleVisible();
                    } else {
                      setState(() => _isPasswordVisible = !_isPasswordVisible);
                    }
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildPopupTextField({
    required String hint,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isObscured,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              isObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        ),
      ),
    );
  }

  // LOGIN BUTTON WIDGET
  Widget _buildLoginButton(double screenWidth) {
    return Container(
      width: screenWidth * 0.90,
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}