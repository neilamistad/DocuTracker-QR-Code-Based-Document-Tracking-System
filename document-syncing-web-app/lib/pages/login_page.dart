import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'dart:ui';

import '../utils/password_utils.dart';
import '../widgets/app_background.dart';

import 'main_page.dart';
import '../main.dart';

class OtherOfficeLoginPage extends StatefulWidget {
  const OtherOfficeLoginPage({super.key});

  @override
  State<OtherOfficeLoginPage> createState() => _OtherOfficeLoginPageState();
}

class _OtherOfficeLoginPageState extends State<OtherOfficeLoginPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool isAccepted = false;

  String? errorMsg;

  // LOGIN FUNCTION 
  Future<void> login() async {
    if (!isAccepted) {
      _showTopNotification(
        "Please read and accept the Terms & Conditions to proceed.", 
        Colors.redAccent
      );
      return;
    }

    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => errorMsg = "Please enter username and password");
      return;
    }

    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {

      final data = await supabase
          .from('other_office_accounts')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (data == null) {
        setState(() {
          errorMsg = "Account not found";
          isLoading = false;
        });
        return;
      }

      final isValid = verifyPassword(password, data['password_hash']);

      if (!isValid) {
        setState(() {
          errorMsg = "Invalid password";
          isLoading = false;
        });
        return;
      }

      try {
        String? fcmToken = await FirebaseMessaging.instance.getToken(
          vapidKey: "BHZWBDkHQfKqbQg0VzzLZ-DE69fxgBInwDCtRfbqCP8-iTnD4VWnQII-qHqMZQRwve9yOB7cv1VoQG83C2vHjaM" 
        );

        if (fcmToken != null) {
          List<dynamic> currentTokens = data['fcm_token'] ?? [];

          if (!currentTokens.contains(fcmToken)) {
            currentTokens.add(fcmToken);
            
            await supabase
                .from('other_office_accounts')
                .update({'fcm_token': currentTokens})
                .eq('office_id', data['office_id']);
          }
        }
      } catch (fcmError) {
        debugPrint("FCM Token Error: ${fcmError.toString()}");
      }

      String storedHash = data['password_hash'];

      if (storedHash.length < 30 && !storedHash.startsWith('\$2a\$')) { 
        final hashed = hashPassword(storedHash);
        await supabase
          .from('other_office_accounts')
          .update({'password_hash': hashed})
          .ilike('username', username);
        storedHash = hashed;
      }

      if (!mounted) return;

      await SessionManager.saveLogin(
        data['office_name'].toString(), 
        data['office_id'].toString(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtherOfficeMainPage(
            officeId: data['office_id'].toString(),
            officeName: data['office_name'],
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = "Login failed. Please try again.";
          isLoading = false;
        });
      }
      debugPrint("Login Error: ${e.toString()}");
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


  // FORGOT PASSWORD LOGIC
  void _handleForgotPassword() {
    final userReqCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isPopupLoading = false;
    bool isNewObscured = true;
    bool isConfirmObscured = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) {
          return Dialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            child: Container(
              width: 450,
              padding: const EdgeInsets.all(30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Request Password Change",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your request will be sent to the Admin for approval.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 25),
                    
                    _buildPopupField(userReqCtrl, "Enter your Username"),
                    const SizedBox(height: 15),
                    
                    _buildPopupField(
                      newPassCtrl, 
                      "New Password", 
                      isPass: true, 
                      obscured: isNewObscured,
                      onToggle: () => setPopupState(() => isNewObscured = !isNewObscured)
                    ),
                    const SizedBox(height: 15),
                    
                    _buildPopupField(
                      confirmPassCtrl, 
                      "Confirm Password", 
                      isPass: true, 
                      obscured: isConfirmObscured,
                      onToggle: () => setPopupState(() => isConfirmObscured = !isConfirmObscured)
                    ),
                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isPopupLoading ? null : () => Navigator.pop(context),
                            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A24C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: isPopupLoading ? null : () async {
                              final user = userReqCtrl.text.trim();
                              final pass = newPassCtrl.text.trim();
                              
                              if (user.isEmpty || pass.isEmpty || confirmPassCtrl.text.isEmpty) {
                                _showToast("Please fill all fields", isError: true);
                                return;
                              }
                              if (pass != confirmPassCtrl.text.trim()) {
                                _showToast("Passwords do not match", isError: true);
                                return;
                              }

                              setPopupState(() => isPopupLoading = true);

                              try {

                                final account = await supabase
                                    .from('other_office_accounts')
                                    .select('username, office_id')
                                    .eq('username', user)
                                    .maybeSingle();

                                if (account == null) {
                                  _showToast("Username not found in Other Office accounts records.", isError: true);
                                  setPopupState(() => isPopupLoading = false);
                                  return;
                                }

                                await supabase.from('password_requests').insert({
                                  'email_or_username': user,
                                  'new_password': hashPassword(pass),
                                  'status': 'pending',
                                  'user_type': 'other_office',
                                  'user_id': account['office_id'].toString(),
                                  'created_at': DateTime.now().toIso8601String(),
                                });

                                if (!mounted) return;
                                Navigator.pop(context);
                                _showToast("Request sent! Wait for Admin approval.");
                              } catch (e) {
                                debugPrint(e.toString());
                                _showToast("System error. Try again later.", isError: true);
                              } finally {
                                if (mounted) setPopupState(() => isPopupLoading = false);
                              }
                            },
                            child: isPopupLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Submit Request", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTermsDialog() {
    final ScrollController _termsScrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: const Color(0xFF121212),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.45,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                // --- CUSTOM HEADER ---
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: Color(0xFFE6AD3E), size: 28),
                      const SizedBox(width: 15),
                      const Text(
                        "Terms and Conditions",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white38),
                      ),
                    ],
                  ),
                ),

                // --- SCROLLABLE CONTENT ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(35, 20, 35, 10),
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: _termsScrollController, // 2. I-bind ang controller dito
                      child: SingleChildScrollView(
                        controller: _termsScrollController, // 3. I-bind din dito sa view
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTermSection("1. Accuracy of Status Updates", 
                              "Each office is responsible for ensuring that the status of every document is accurate and updated in a timely manner."),
                            _buildTermSection("2. Data Synchronization", 
                              "While the system supports offline data entry, status updates are only officially reflected across the network once synchronized. Users are responsible for ensuring that their devices are connected to the internet periodically to complete the data sync. The system is not liable for data discrepancies or delays caused by pending synchronization or local network failures."),
                            _buildTermSection("3. Authorized Access", 
                              "Access is strictly limited to authorized personnel. Sharing of credentials or leaving the terminal unattended is prohibited."),
                            _buildTermSection("4. Privacy and Confidentiality", 
                              "All data handled within this system must be treated as confidential in accordance with the Data Privacy Act of 2012."),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- BOTTOM ACTION ---
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34A24C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "I UNDERSTAND",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
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

// Helper function para sa malinis na format ng bawat section



  // MAIN UI OF THE APP
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 80,
              vertical: 0,
            ),
            child: 
            Row(
              children: [
                Expanded(flex: 5, child: _buildWelcomeSection()),
                const SizedBox(width: 50),
                Expanded(flex: 4, child: _buildLoginCard()),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // OTHER UI BLOCKS:

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF006A60), Color(0xFF92BC36), Color(0xFF004D28)],
            stops: [0.16, 0.54, 0.98],
          ).createShader(bounds),
          child: Text(
            'Welcome Back',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.w700,
              fontFamily: 'Noto Sans Hebrew',
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Please sign in to securely access your document tracking dashboard.',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 24,
            fontWeight: FontWeight.w200,
          ),
        ),
      ],
    );
  }

  // LOGIN CARD (Glass morphism)
  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 550), 
      padding: EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Other Office Login',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          
          _buildField(
            usernameCtrl, 
            "Username", 
            Icons.person_outline,
            onEnter: isLoading ? null : login,
          ),
          const SizedBox(height: 20),
          
          _buildField(
            passwordCtrl, 
            "Password", 
            Icons.lock_outline, 
            isPass: true,
            obscure: obscurePassword,
            onToggle: () => setState(() => obscurePassword = !obscurePassword),
            onEnter: isLoading ? null : login,
          ),
          
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword, 
              child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFE6AD3E))),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center, // I-center ang checkbox at text
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Theme(
                data: ThemeData(unselectedWidgetColor: Colors.white30),
                child: Checkbox(
                  value: isAccepted,
                  activeColor: const Color(0xFF92BC36),
                  checkColor: Colors.white,
                  onChanged: (val) => setState(() => isAccepted = val ?? false),
                ),
              ),
              // Gamit ang Flexible para hindi mag-overflow at mag-wrap ang text
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      "I have read the ",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: _showTermsDialog,
                      child: const Text(
                        "Terms & Conditions",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),

          _buildLoginButton(),
          
          if (errorMsg != null) ...[
            const SizedBox(height: 15),
            Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
          ]
        ],
      ),
    );
  }

  // REUSABLE INPUT FIELD
  Widget _buildField(
    TextEditingController ctrl, 
    String hint, 
    IconData icon, {
    bool isPass = false, 
    bool obscure = false, 
    VoidCallback? onToggle,
    VoidCallback? onEnter,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass ? obscure : false,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        
        onSubmitted: (_) {
          if (onEnter != null) onEnter();
        },
        
        textInputAction: isPass ? TextInputAction.done : TextInputAction.next,

        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: const Color(0xFF92BC36)),
          
          suffixIcon: isPass 
            ? Padding(
                padding: const EdgeInsets.only(right: 15),
                child: IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility, 
                    color: Colors.white38,
                    size: 22,
                  ),
                  onPressed: onToggle,
                ),
              ) 
            : null,
            
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return InkWell(
      onTap: isLoading ? null : login,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B4338), Color(0xFF418948), Color(0xFF79D24E), Color(0xFF0A473A)],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: isLoading 
            ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  // REUSABLE POPUP FIELD
  Widget _buildPopupField(TextEditingController ctrl, String hint, {bool isPass = false, bool obscured = false, VoidCallback? onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass ? obscured : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Color(0xFF78CF4E)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF78CF4E))),
        suffixIcon: isPass ? IconButton(
          icon: Icon(obscured ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
          onPressed: onToggle,
        ) : null,
      ),
    );
  }
  Widget _buildTermSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF92BC36), // Green color para sa titles
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // SNACKBAR POPUP
  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}