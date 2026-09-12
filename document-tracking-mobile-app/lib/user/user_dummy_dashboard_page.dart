import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../widgets/background_wrapper.dart';
import '../widgets/user_navigation_bar_wrapper.dart';

class UserDummyDashboardPage extends StatefulWidget {
  final String userId;
  final String userType;

  const UserDummyDashboardPage({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<UserDummyDashboardPage> createState() => _UserDummyDashboardPageState();
}

class _UserDummyDashboardPageState extends State<UserDummyDashboardPage> {
  final supabase = Supabase.instance.client;

  // DEFINE TUTORIAL KEYS
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  
  // NAVIGATION KEYS
  final GlobalKey _navDashboardKey = GlobalKey();
  final GlobalKey _navSearchKey = GlobalKey();
  final GlobalKey _navAddKey = GlobalKey();
  final GlobalKey _navTrackingKey = GlobalKey();
  final GlobalKey _navSettingsKey = GlobalKey();

  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNavigationTutorial();
    });
  }

  // FINISH LOGIC
  Future<void> _finishTour() async {
    try {
      final String type = widget.userType.toLowerCase();
      final table = type == 'faculty' ? 'faculty_accounts' : 'student_org_accounts';
      final idCol = type == 'faculty' ? 'faculty_id' : 'org_id';

      await supabase.from(table).update({'first_time_user': false}).eq(idCol, widget.userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserNavigationBarWrapper(userType: widget.userType, userId: widget.userId)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserNavigationBarWrapper(userType: widget.userType, userId: widget.userId)),
        );
      }
    }
  }

  // TUTORIAL LOGIC
  void _showNavigationTutorial() {
    _initTargets();
    TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF0D0D0D),
      opacityShadow: 0.9,
      textSkip: "SKIP",
      paddingFocus: 10,
      pulseEnable: true,
      onFinish: _finishTour,
      onSkip: () {
        _finishTour();
        return true;
      },
    ).show(context: context);
  }

  void _initTargets() {
    targets.clear();
    targets.add(_createTarget("header", _headerKey, "Welcome to CvSU-CCAT Document Tracker!", "This is your personalized dashboard where you can see your account details and document status.", ContentAlign.bottom));
    targets.add(_createTarget("stats", _statsKey, "Quick Stats", "Get a summarized view of the status of all your registered documents at a glance.", ContentAlign.bottom));
    targets.add(_createTarget("history", _historyKey, "Recent Activity", "Monitor the latest movements and updates of your files across different offices.", ContentAlign.top));
    targets.add(_createTarget("navDash", _navDashboardKey, "Dashboard", "Return to this main overview page anytime to see your document summary.", ContentAlign.top));
    targets.add(_createTarget("navSearch", _navSearchKey, "Document Search", "Quickly find documents by their unique Document ID for their information and current status.", ContentAlign.top));
    targets.add(_createTarget("navAdd", _navAddKey, "Register Document", "Tap this button to create and register a new document into the tracking system.", ContentAlign.top));
    targets.add(_createTarget("navTrack", _navTrackingKey, "Full History", "View the complete step-by-step logs of all documents you have registered.", ContentAlign.top));
    targets.add(_createTarget("navSet", _navSettingsKey, "Account Settings", "Manage your profile information and account security from here.", ContentAlign.top));
  }

  TargetFocus _createTarget(String id, GlobalKey key, String title, String desc, ContentAlign align) {
    return TargetFocus(
      identify: id,
      keyTarget: key,
      contents: [
        TargetContent(
          align: align,
          child: _tutorialBubble(title, desc),
        ),
      ],
    );
  }

  Widget _tutorialBubble(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF8BB839), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF8BB839), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerRight,
            child: Text("TAP INSIDE THE AREA TO CONTINUE →", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(25, 60, 25, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(key: _headerKey),
              const SizedBox(height: 35),

              const Text("Documents Quick Overview", 
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.1)),
              const SizedBox(height: 15),
              
              Row(
                key: _statsKey,
                children: [
                  _buildStatCard("On Process", "5", Colors.orangeAccent),
                  const SizedBox(width: 15),
                  _buildStatCard("Received Back", "12", Colors.green),
                ],
              ),

              const SizedBox(height: 40),

              Row(
                key: _historyKey,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Tracking History", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 20),
                ],
              ),
              const SizedBox(height: 25),
              
              _buildStaticTimelineItem("DOC-2024-001", "Registered", "APR 05, 2026 | 09:00 AM"),
              _buildStaticTimelineItem("DOC-2024-005", "Received back", "APR 04, 2026 | 02:30 PM"),
              _buildStaticTimelineItem("DOC-2024-012", "Signed", "APR 03, 2026 | 11:15 AM"),
            ],
          ),
        ),
      ),
      
      // REPLICA NAVIGATION BAR
      floatingActionButton: _buildReplicaFAB(key: _navAddKey),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 12.0,
        color: const Color(0xFF141414),
        elevation: 0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReplicaNavItem(Icons.grid_view_rounded, true, _navDashboardKey),
              _buildReplicaNavItem(Icons.search_rounded, false, _navSearchKey),
              const SizedBox(width: 70), 
              _buildReplicaNavItem(Icons.assignment_turned_in_rounded, false, _navTrackingKey),
              _buildReplicaNavItem(Icons.person_rounded, false, _navSettingsKey),
            ],
          ),
        ),
      ),
    );
  }

  // REPLICA UI HELPERS

  Widget _buildHeader({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF078B7E), Color(0xFF92BC36), Color(0xFF1AB168)]).createShader(Offset.zero & bounds.size),
          child: const Text("Greetings, User!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF8BB839).withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8BB839).withOpacity(0.3))),
          child: Text(widget.userType.toUpperCase(), style: const TextStyle(color: Color(0xFF92BC36), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticTimelineItem(String title, String status, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 10, color: Color(0xFF8BB839)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(status, style: const TextStyle(color: Color(0xFF8BB839), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplicaFAB({required Key key}) {
    return Container(
      key: key,
      child: FloatingActionButton(
        onPressed: null,
        backgroundColor: const Color(0xFF8BB839),
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildReplicaNavItem(IconData icon, bool isSelected, Key key) {
    return Expanded(
      child: Center(
        key: key,
        child: Icon(icon, color: isSelected ? const Color(0xFF8BB839) : Colors.white24, size: 24),
      ),
    );
  }
}