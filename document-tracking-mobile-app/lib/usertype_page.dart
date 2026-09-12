import 'package:flutter/material.dart';

import '../widgets/background_wrapper.dart';

import 'faculty_login_page.dart';
import 'student_org_login_page.dart';

class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TITLE SECTION
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
                    'Identify Your Access Type',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.12,
                      fontFamily: 'Noto Sans Hebrew',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                Text(
                  'Please select your role to proceed to the appropriate dashboard.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 60),

                // BUTTONS
                _buildRoleButton(
                  context,
                  title: 'FACULTY',
                  isGradient: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FacultyLoginPage()),
                    );
                  },
                ),

                const SizedBox(height: 20),

                _buildRoleButton(
                  context,
                  title: 'STUDENT ORGANIZATION',
                  isGradient: false,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentOrgLoginPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // REUSABLE ROLE BUTTON WIDGET
  Widget _buildRoleButton(
    BuildContext context, {
    required String title,
    required bool isGradient,
    required VoidCallback onPressed,
  }) {
    final double width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: width * 0.75,
        height: 55,
        child: isGradient 
          ?
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF0B4338),
                    Color(0xFF418948),
                    Color(0xFF8BB839),
                    Color(0xFF488F46),
                    Color(0xFF50AB7F),
                  ],
                ),
              ),
              child: Center(child: _buttonText(title, 20)),
            )
          :
            Stack(
              children: [

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: const LinearGradient(
                      begin: Alignment(-0.866, -0.5),
                      end: Alignment(0.866, 0.5),
                      colors: [
                        Color(0xFF006A60),
                        Color(0xFF51AC80),
                        Color(0xFFE6AD3E),
                        Color(0xFF79D24E),
                        Color(0xFF51AC80),
                      ],
                      stops: [0.0, 0.19, 0.52, 0.81, 1.0],
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 141, 141, 141),
                    borderRadius: BorderRadius.circular(38),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(38),
                  ),
                  child: Center(
                    child: _buttonText(title, 16),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // REUSABLE BUTTON TEXT
  Widget _buttonText(String title, double fontSize) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontFamily: 'Noto Sans Hebrew',
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}