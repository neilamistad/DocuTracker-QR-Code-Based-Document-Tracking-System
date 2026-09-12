import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/main_wrapper.dart';

class DummyDashboardPage extends StatefulWidget {
  final String userType;
  final String userId;

  const DummyDashboardPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<DummyDashboardPage> createState() => _DummyDashboardPageState();
}

class _DummyDashboardPageState extends State<DummyDashboardPage> {
  final supabase = Supabase.instance.client;
  final ScrollController _navScrollController = ScrollController();
  int _currentStep = 0;
  final bool _isTourActive = true;

  final List<Map<String, String>> _tourSteps = [
    {"title": "Welcome to CvSU Document Tracker!", "desc": "This is your main dashboard summary.", "target": "Dashboard Overview"},
    {"title": "Document Search", "desc": "Find documents instantly by name or ID.", "target": "Search Page"},
    {"title": "Document Registration", "desc": "Register new physical documents here.", "target": "Registration Page"},
    {"title": "Tracking History", "desc": "Track the full audit trail of your documents.", "target": "History Page"},
    {"title": "Profile & Security", "desc": "Manage your account details and security.", "target": "Account Page"},
  ];

  void _scrollToActiveStep(int index, bool isMobile) {
    if (isMobile && _navScrollController.hasClients) {
      double itemWidth = 145.0; 
      double screenWidth = MediaQuery.of(context).size.width;
      double offset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      _navScrollController.animateTo(
        offset.clamp(0.0, _navScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep(bool isMobile) {
    setState(() {
      if (_currentStep < _tourSteps.length - 1) {
        _currentStep++;
        _scrollToActiveStep(_currentStep, isMobile);
      } else {
        _finishTour();
      }
    });
  }

  Future<void> _finishTour() async {
    try {
      final table = widget.userType == "faculty" ? 'faculty_accounts' : 'student_org_accounts';
      final idCol = widget.userType == "faculty" ? 'faculty_id' : 'org_id';
      await supabase.from(table).update({'first_time_user': false}).eq(idCol, widget.userId);

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainWrapper(userType: widget.userType, userId: widget.userId)),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 1100;

          return Stack(
            children: [
              AppBackground(
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildNavbar(isDesktop),
                      _buildContent(isDesktop),
                    ],
                  ),
                ),
              ),
              if (_isTourActive)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.2),
                  child: Center(child: _buildTourCard(isDesktop)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTourCard(bool isDesktop) {
    return Container(
      width: isDesktop ? 450 : 350,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF00120A),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF50AB7F), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFF78CF4E).withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("GUIDE: ${_tourSteps[_currentStep]['target']}", style: const TextStyle(color: Color(0xFF78CF4E), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 20),
          Text(_tourSteps[_currentStep]['title']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text(_tourSteps[_currentStep]['desc']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: _finishTour, child: const Text("Skip Tour", style: TextStyle(color: Colors.white30))),
              ElevatedButton(
                onPressed: () => _nextStep(!isDesktop),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF50AB7F)),
                child: Text(_currentStep == _tourSteps.length - 1 ? "Finish" : "Next Step"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavbar(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: isDesktop 
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _navButtons(true),
          )
        : SingleChildScrollView(
            controller: _navScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: [const SizedBox(width: 20), ..._navButtons(false), const SizedBox(width: 20)]),
          ),
    );
  }

  List<Widget> _navButtons(bool isDesktop) {
    return [
      _NavButton(label: 'Dashboard', isActive: _currentStep == 0, isDesktop: isDesktop),
      _NavButton(label: 'Document Search', isActive: _currentStep == 1, isDesktop: isDesktop),
      _NavButton(label: 'Document Registration', isActive: _currentStep == 2, isDesktop: isDesktop),
      _NavButton(label: 'Tracking History', isActive: _currentStep == 3, isDesktop: isDesktop),
      _NavButton(label: 'Account', isActive: _currentStep == 4, isDesktop: isDesktop),
    ];
  }

  Widget _buildContent(bool isDesktop) {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 100 : 25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('Welcome, User!', style: TextStyle(fontSize: isDesktop ? 70 : 40, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 50),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: isDesktop ? 3 : 1,
              mainAxisSpacing: 30,
              crossAxisSpacing: 30,
              childAspectRatio: 1.5,
              children: const [
                _DashboardCard(title: "WEEKLY REGISTERED"),
                _DashboardCard(title: "TOTAL REGISTERED"),
                _DashboardCard(title: "RECEIVED BACK"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDesktop;
  const _NavButton({required this.label, required this.isActive, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isDesktop ? null : 135,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 10, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isActive ? const Color(0xFF78CF4E) : Colors.white24, width: isActive ? 2 : 1),
      ),
      child: Text(
        label, 
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  const _DashboardCard({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFFE6AD3E))),
      child: Center(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12))),
    );
  }
}