import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/background_wrapper.dart'; 

import 'usertype_page.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(minHeight: screenHeight - MediaQuery.of(context).padding.top),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),

                  Center(
                    child: Image.asset(
                      "assets/images/get_started_image.png",
                      width: screenWidth * 0.8,
                      height: screenHeight * 0.3,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // TITLE
                  Text(
                    'Let’s Keep Your\nDocuments on Track',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.09,
                      fontFamily: 'Noto Sans Hebrew',
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Experience fast, organized, and hassle-free document tracking with real-time updates anytime, anywhere.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Noto Sans Hebrew',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20), 

                  Center(child: _buildGradientButton(screenWidth, context)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // REUSABLE GRADIENT BUTTON
  Widget _buildGradientButton(double width, BuildContext context) {
    return Container(
      width: width * 0.65,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0B4338),
            Color(0xFF418948),
            Color(0xFF8BB839),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isAppFirstTime', false);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserTypePage()),
            );
          },
          child: const Center(
            child: Text(
              "Get Started",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}