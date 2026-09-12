import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../widgets/app_background.dart'; 
import '../utils/password_utils.dart';
import 'faculty_login_page.dart';

class FacultyRegistrationPage extends StatefulWidget {
  final String userType;

  const FacultyRegistrationPage({super.key, required this.userType});

  @override
  State<FacultyRegistrationPage> createState() => _FacultyRegistrationPageState();
}

class _FacultyRegistrationPageState extends State<FacultyRegistrationPage> {
  final supabase = Supabase.instance.client;

  String? selectedCourse;
  List<String> courses = []; 
  bool isLoadingCourses = true;

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final facultyIdCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      final data = await supabase
          .from('courses')
          .select('course_name')
          .order('course_name', ascending: true);

      if (mounted) {
        setState(() {
          courses = List<String>.from(data.map((item) => item['course_name']));
          isLoadingCourses = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      if (mounted) {
        setState(() => isLoadingCourses = false);
      }
    }
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    facultyIdCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> submitRequest() async {
    final firstName = firstNameCtrl.text.trim();
    final lastName = lastNameCtrl.text.trim();
    final facultyId = facultyIdCtrl.text.trim();
    final email = emailCtrl.text.trim().toLowerCase();
    final course = selectedCourse;
    final password = passwordCtrl.text.trim();
    final confirmPassword = confirmPasswordCtrl.text.trim();

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
      _showTopNotification('Passwords do not match. Please try again.', Colors.red);
      return;
    }

    setState(() => isLoading = true);

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

      if (!mounted) return;

      _showTopNotification('Registration request submitted! Please wait for Admin approval.', Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => FacultyLoginPage(userType: "faculty")),
        (route) => false,
      );
      
    } on PostgrestException catch (error) {
      debugPrint("Supabase Error: ${error.message}");
      _showTopNotification('Unable to process request. The ID or Email might already be in use.', Colors.red);
    } catch (e) {
      debugPrint("General Error: $e");
      _showTopNotification('A connection error occurred. Please try again later.', Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 1100;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 80 : 20, 
                      vertical: isDesktop ? 20 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNonStickyBackButton(isDesktop),
                        
                        isDesktop
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(flex: 4, child: _buildWelcomeText(screenWidth)),
                                    const SizedBox(width: 80),
                                    Expanded(flex: 3, child: _buildRegistrationCard(context)),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  _buildWelcomeText(screenWidth),
                                  const SizedBox(height: 40),
                                  _buildRegistrationCard(context),
                                ],
                              ),
                        
                        const SizedBox(height: 20),
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

  Widget _buildNonStickyBackButton(bool isDesktop) {
    return Transform.translate(
      offset: Offset(isDesktop ? -60.0 : -20.0, 20.0), 
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
                size: isDesktop ? 22 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(double screenWidth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Begin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth > 600 ? 65 : 35,
                  fontFamily: 'Noto Sans Hebrew',
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '\nTracking with Your Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth > 600 ? 65 : 35,
                  fontFamily: 'Noto Sans Hebrew',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 15),
        Text(
          'Please provide the required information to get started.',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.white, 
            fontSize: screenWidth > 600 ? 18 : 14, 
            fontFamily: 'Noto Sans Hebrew', 
            fontWeight: FontWeight.w200
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Faculty Registration',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: _buildTextField('First name', firstNameCtrl, context)),
              const SizedBox(width: 10),
              Expanded(child: _buildTextField('Last name', lastNameCtrl, context)),
            ],
          ),
          _buildTextField('Faculty ID', facultyIdCtrl, context),
          _buildTextField('CVSU email (@cvsu.edu.ph)', emailCtrl, context),
          _buildDropdownField(context),
          _buildTextField('Password', passwordCtrl, context, isPassword: true, isObscured: obscurePassword, 
            onToggle: () => setState(() => obscurePassword = !obscurePassword)),
          _buildTextField('Confirm password', confirmPasswordCtrl, context, isPassword: true, isObscured: obscureConfirmPassword, 
            onToggle: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword)),
          const SizedBox(height: 20),
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl, BuildContext context, {bool isPassword = false, bool? isObscured, VoidCallback? onToggle}) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword ? (isObscured ?? true) : false,
        textAlign: TextAlign.left,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Color(0xCCD9D9D9), 
            fontSize: isMobile ? 12 : 14, 
            fontWeight: FontWeight.w300
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), 
          suffixIcon: isPassword ? Padding(
            padding: const EdgeInsets.only(right: 10), 
            child: IconButton(
              icon: Icon(
                isObscured! ? Icons.visibility : Icons.visibility_off, 
                color: Colors.white70, 
                size: 20
              ),
              onPressed: onToggle,
            ),
          ) : null,
        ),
      ),
    );
  }

  Widget _buildDropdownField(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCourse,
          isExpanded: true,
          dropdownColor: const Color(0xFF00120A),
          icon: isLoadingCourses 
              ? const SizedBox(
                  width: 15, 
                  height: 15, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
                )
              : const Icon(Icons.arrow_drop_down, color: Colors.white70),
          
          selectedItemBuilder: (BuildContext context) {
            return courses.map<Widget>((String item) {
              return Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 15,
                  ),
                ),
              );
            }).toList();
          },
          
          hint: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isLoadingCourses ? 'Loading Courses...' : 'Select Course',
              style: const TextStyle(
                color: Color(0xCCD9D9D9),
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),

          items: courses.map((c) => DropdownMenuItem(
            value: c,
            child: Text(
              c,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          )).toList(),
          onChanged: isLoadingCourses ? null : (val) => setState(() => selectedCourse = val),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Center(
      child: Container(
        width: 180,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0B4338), 
              Color(0xFF418948), 
              Color(0xCC8BB839), 
              Color(0xFF488F46), 
              Color(0xFF0A473A)
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : submitRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),

              Opacity(
                opacity: isLoading ? 0.0 : 1.0,
                child: const Text(
                  'REGISTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}