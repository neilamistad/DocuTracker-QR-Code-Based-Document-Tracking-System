import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/services.dart' show rootBundle;

import '../widgets/background_wrapper.dart';

import 'utils/password_hashing.dart';

import 'faculty_login_page.dart';

class FacultyRegistrationPage extends StatefulWidget {
  const FacultyRegistrationPage({super.key});

  @override
  State<FacultyRegistrationPage> createState() => _FacultyRegistrationPageState();
}

class _FacultyRegistrationPageState extends State<FacultyRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final facultyIdCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final deptCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  List<String> _courses = []; 
  String? _selectedCourse;    
  bool _isLoadingCourses = true;

  @override
  void initState() {
    super.initState();
    _fetchCourses(); 
  }

  Future<void> _fetchCourses() async {
    try {
      final data = await Supabase.instance.client
          .from('courses')
          .select('course_name')
          .order('course_name', ascending: true);

      setState(() {
        _courses = List<String>.from(data.map((item) => item['course_name']));
        _isLoadingCourses = false;
      });
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> submitRequest() async {
    final firstName = firstNameCtrl.text.trim();
    final lastName = lastNameCtrl.text.trim();
    final facultyId = facultyIdCtrl.text.trim();
    final email = emailCtrl.text.trim().toLowerCase();
    final course = _selectedCourse;
    final password = passCtrl.text.trim();
    final confirmPassword = confirmPassCtrl.text.trim();

    FocusScope.of(context).unfocus();

    if (firstName.isEmpty || lastName.isEmpty || facultyId.isEmpty || 
        email.isEmpty || course == null || password.isEmpty || confirmPassword.isEmpty) {
      _showTopNotification('Please fill in all required fields.', Colors.red);
      return;
    }

    final emailRegExp = RegExp(r"^[a-zA-Z0-9.]+@cvsu\.edu\.ph$");
    if (!emailRegExp.hasMatch(email)) {
      _showTopNotification('Please use your official @cvsu.edu.ph email address.', Colors.red);
      return;
    }

    if (password.length < 8) {
      _showTopNotification('Password must be at least 8 characters long.', Colors.red);
      return;
    }
    
    if (password != confirmPassword) {
      _showTopNotification('Passwords do not match.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {

      final existingAccount = await supabase
        .from('faculty_accounts')
        .select()
        .or('faculty_id.eq.$facultyId,cvsu_email.eq.$email')
        .maybeSingle();

      if (existingAccount != null) {
        _showTopNotification('This ID or Email is already registered.', Colors.orange);
        return;
      }

      final existingRequest = await supabase
          .from('faculty_account_registration_requests')
          .select()
          .or('faculty_id.eq.$facultyId,cvsu_email.eq.$email')
          .maybeSingle();

      if (existingRequest != null) {
        if (existingRequest['status'] != 'rejected') {
          String statusMessage = 'A pending registration request already exists for this ID or Email.';     
          _showTopNotification(statusMessage, Colors.orange);
          return;
        }

      }

      final passwordHash = hashPassword(password);
      
      await supabase.from('faculty_account_registration_requests').insert({
        'first_name': firstName,
        'last_name': lastName,
        'faculty_id': facultyId,
        'cvsu_email': email,
        'course': course,
        'password_hash': passwordHash,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        final List<dynamic> admins = await supabase
            .from('admin_accounts')
            .select('fcm_token');

        if (admins.isNotEmpty) {

          final List<String> allAdminTokens = admins
              .expand((admin) => (admin['fcm_token'] as List).map((e) => e.toString()))
              .toSet()
              .toList();

          if (allAdminTokens.isNotEmpty) {

            await Future.wait(allAdminTokens.map((token) => _sendAdminNotificationV1(
              adminToken: token,
              title: "New Faculty Registration",
              body: "$firstName $lastName has requested an account (ID: $facultyId).",
            ).catchError((e) => debugPrint("FCM Error for token $token: $e"))));
          }
        }
      } catch (notifError) {

        debugPrint("Notification broadcast failed: $notifError");
      }

      if (!mounted) return;

      _showTopNotification('Request submitted! Please wait for Admin approval.', Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FacultyLoginPage()),
        (route) => false,
      );
      
    } on PostgrestException catch (error) {
      _showTopNotification('Database error: ${error.message}', Colors.red);
    } catch (e) {
      _showTopNotification('A connection error occurred.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendAdminNotificationV1({
    required String adminToken,
    required String title,
    required String body,
  }) async {
    try {
      final jsonString = await rootBundle.loadString('assets/service-account.json');
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(jsonString);

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);

      const String projectId = 'document-tracking-system-61b9e'; 
      final String url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await client.post(
        Uri.parse(url),
        body: jsonEncode({
          'message': {
            'token': adminToken,
            'notification': {
              'title': title,
              'body': body,
            },

            // FOR MOBILE (Android)
            'android': {
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'notification_sound',
              },
            },
            // FOR WEB/CHROME
            'webpush': {
              'headers': {
                'Urgency': 'high'
              },
              'notification': {
                'icon': '/icons/Icon-192.png',
                'silent': false,
                'sound': 'notification_sound',
                'requireInteraction': true,
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("FCM v1: Admin Notified successfully!");
      } else {
        debugPrint("FCM v1 Error: ${response.body}");
      }
      
      client.close();
    } catch (e) {
      debugPrint("FCM v1 Exception: $e");
    }
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
                    'Begin Tracking with Your Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.10,
                      fontFamily: 'Noto Sans Hebrew',
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Please provide the required information to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 35),

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
                          'Faculty Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 25),

                        _regField('First name', Icons.person_outline, firstNameCtrl),
                        const SizedBox(height: 15),
                        _regField('Last name', Icons.person_outline, lastNameCtrl),
                        const SizedBox(height: 15),
                        _regField('Faculty ID', Icons.badge_outlined, facultyIdCtrl),
                        const SizedBox(height: 15),
                        _regField('CVSU email', Icons.email_outlined, emailCtrl),
                        const SizedBox(height: 15),

                        _buildCourseDropdown(),

                        const SizedBox(height: 15),
                        
                        _regField(
                          'Password', 
                          Icons.lock_outline, 
                          passCtrl, 
                          isPass: true, 
                          obscureText: _obscurePass,
                          onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
                        ),

                        const SizedBox(height: 15),

                        _regField(
                          'Confirm password', 
                          Icons.lock_reset_outlined, 
                          confirmPassCtrl, 
                          isPass: true, 
                          obscureText: _obscureConfirm,
                          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),

                        const SizedBox(height: 30),

                        _buildSubmitRequestButton(screenWidth),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Log In",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseDropdown() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, color: Colors.white70, size: 20),
          const SizedBox(width: 20),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCourse,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                dropdownColor: const Color(0xFF1A1A1A),
                hint: Text(
                  _isLoadingCourses ? 'Loading...' : 'Select Course',
                  style: TextStyle(
                    color: Colors.white70.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                selectedItemBuilder: (BuildContext context) {
                  return _courses.map<Widget>((String item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    );
                  }).toList();
                },
                items: _courses.map((String course) {
                  return DropdownMenuItem<String>(
                    value: course,
                    child: Text(course, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCourse = val;
                  });
                },
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REUSABLE TEXTFIELD BUILDER
  Widget _regField(
    String hint, 
    IconData icon, 
    TextEditingController ctrl, {
    bool isPass = false, 
    bool obscureText = false, 
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
      ),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPass ? obscureText : false,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xCCD9D9D9), fontWeight: FontWeight.w300),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          
          suffixIcon: isPass 
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white60,
                  size: 18,
                ),
                onPressed: onSuffixTap,
              )
            : null,
            
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        ),
      ),
    );
  }

  // GRADIENT REGISTER BUTTON
  Widget _buildSubmitRequestButton(double width) {
    return Container(
      width: width * 0.5,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B4338), Color(0xFF418948), Color(0xFF8BB839), Color(0xFF488F46), Color(0xFF0A473A)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('SUBMIT REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}