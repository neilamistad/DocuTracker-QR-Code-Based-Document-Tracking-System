import 'dart:ui';
import 'package:flutter/material.dart';
import 'student_org_login_page.dart';
import 'faculty_login_page.dart';
import '../widgets/app_background.dart';
import 'package:material_symbols_icons/symbols.dart';

class VerticalFolderClipper extends CustomClipper<Path> {
  final double tabLength;
  final double tabWidth;

  VerticalFolderClipper({this.tabLength = 320, this.tabWidth = 55});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double corner = 15;

    path.moveTo(0, 0); 
    path.lineTo(0, tabLength - 30);
    path.lineTo(tabWidth, tabLength);
    
    path.lineTo(tabWidth, size.height - corner);
    path.lineTo(tabWidth + corner, size.height);
    path.lineTo(size.width - corner, size.height);
    path.lineTo(size.width, size.height - corner);
    
    path.lineTo(size.width, corner);
    path.lineTo(size.width - corner, 0);
    
    path.lineTo(tabWidth, 0);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class FolderBorderPainter extends CustomPainter {
  final double tabLength;
  final double tabWidth;

  FolderBorderPainter({required this.tabLength, required this.tabWidth});

  @override
  void paint(Canvas canvas, Size size) {
    double corner = 15;
    
    Path path = Path();
    path.moveTo(0, 0); 
    path.lineTo(0, tabLength - 30);
    path.lineTo(tabWidth, tabLength);
    path.lineTo(tabWidth, size.height - corner);
    path.lineTo(tabWidth + corner, size.height);
    path.lineTo(size.width - corner, size.height);
    path.lineTo(size.width, size.height - corner);
    path.lineTo(size.width, corner);
    path.lineTo(size.width - corner, 0);
    path.lineTo(tabWidth, 0);
    path.close();

    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE6AD3E),
          Color(0xFF51AC80),
          Color(0xFFE6AD3E),
          Color(0xFF79D24E),
        ],
        stops: [0.0, 0.35, 0.59, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1100;

    return Scaffold(
      body: AppBackground(
        child: isMobile 
          ? _buildMobileLayout(context) 
          : _buildDesktopLayout(context),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 150,
                child: Column(
                  children: const [
                    Text(
                      'Identify Your Access Type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 86,
                        fontFamily: 'Noto Sans Hebrew',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Select your role to access the document tracking dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 28,
                        fontFamily: 'Noto Sans Hebrew',
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ],
                ),
              ),


              Positioned(
                left: 450,
                top: 380,
                child: _buildRoleButton(
                  context,
                  label: 'STUDENT ORG',
                  icon: Symbols.group,
                  isMobile: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const OrgLoginPage(userType: 'student org'),
                  )),
                ),
              ),

              Positioned(
                right: 450,
                top: 380,
                child: _buildRoleButton(
                  context,
                  label: 'FACULTY',
                  icon: Symbols.badge_rounded,
                  isMobile: false,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const FacultyLoginPage(userType: 'faculty'),
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MOBILE LAYOUT
  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Identify Your Access Type',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Select your role to access the dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 50),
              _buildRoleButton(
                context,
                label: 'STUDENT ORG',
                icon: Symbols.group,
                isMobile: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const OrgLoginPage(userType: 'student org'),
                )),
              ),
              const SizedBox(height: 30),
              _buildRoleButton(
                context,
                label: 'FACULTY',
                icon: Symbols.badge_rounded,
                isMobile: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const FacultyLoginPage(userType: 'faculty'),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADAPTIVE ROLE BUTTON
  Widget _buildRoleButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    final double folderWidth = isMobile ? 320 : 450;
    final double folderHeight = isMobile ? 420 : 550;
    final double currentTabLength = isMobile ? 240 : 320;
    final double currentTabWidth = isMobile ? 38 : 45;

    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Stack(
        children: [
          ClipPath(
            clipper: VerticalFolderClipper(
              tabLength: currentTabLength,
              tabWidth: currentTabWidth,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: folderWidth,
                height: folderHeight,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          CustomPaint(
            size: Size(folderWidth, folderHeight),
            painter: FolderBorderPainter(
              tabLength: currentTabLength,
              tabWidth: currentTabWidth,
            ),
          ),
          SizedBox(
            width: folderWidth,
            height: folderHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: SizedBox(
                    width: currentTabWidth,
                    height: currentTabLength,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: const Color(0xFF79D14E),
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: isMobile ? 3 : 5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(left: currentTabWidth),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF79D14E), Color(0xFFB4F59E)],
                      ).createShader(bounds),
                      child: Icon(
                        icon,
                        size: isMobile ? 150 : 210,
                        color: Colors.white.withOpacity(0.2),
                        weight: 100,
                        fill: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}