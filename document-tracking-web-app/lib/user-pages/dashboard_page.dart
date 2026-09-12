import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/notification_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  final String userType;
  final String userId;

  const DashboardPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  
  int weeklyCount = 0;
  int totalCount = 0;
  int receivedCount = 0;
  String displayName = "User";
  bool isLoading = true;
  RealtimeChannel? _dashboardChannel;

  @override
  void initState() {
    super.initState();
    _saveSession();
    _initNotificationSystem();
    _setupRealtimeDashboard();
  }

  @override
  void dispose() {
    _dashboardChannel?.unsubscribe();
    super.dispose();
  }

  void _initNotificationSystem() {
    Future.delayed(Duration.zero, () async {
      if (!NotificationUtils.isInitialized) {
        await NotificationUtils.syncInitialBadgeCounts(widget.userId);
        NotificationUtils.initializeListeners(widget.userId);
      } else {
        await NotificationUtils.syncInitialBadgeCounts(widget.userId);
      }
    });
  }

  void _setupRealtimeDashboard() async {
    await _fetchInitialData();

    _dashboardChannel = supabase
        .channel('public:user_dashboard_${widget.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'registered_by_id',
            value: widget.userId.toString(),
          ),
          callback: (payload) {
            print("Signal Received!");
            _refreshCountsOnly();
          },
        );
    
    _dashboardChannel!.subscribe();
  }

  Future<void> _fetchInitialData() async {
    try {
      if (widget.userType == 'faculty') {
        final res = await supabase
            .from('faculty_accounts')
            .select('first_name')
            .eq('faculty_id', widget.userId)
            .single();
        displayName = res['first_name'] ?? "Faculty";
      } else {
        final res = await supabase
            .from('student_org_accounts')
            .select('org_name')
            .eq('org_id', widget.userId)
            .single();
        displayName = res['org_name'] ?? "Organization";
      }

      await _refreshCountsOnly();
    } catch (e) {
      debugPrint("Initial Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _refreshCountsOnly() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekStr = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toIso8601String();

    try {
      final response = await supabase
          .from('documents')
          .select('document_id, current_status, registered_at')
          .eq('registered_by_id', widget.userId);

      if (mounted) {
        final List allMyDocs = response as List;

        setState(() {
          // TOTAL COUNT
          totalCount = allMyDocs.length;

          // RECEIVED COUNT
          receivedCount = allMyDocs
              .where((d) => d['current_status'] == 'Received Back')
              .length;

          // WEEKLY COUNT
          weeklyCount = allMyDocs.where((d) {
            final regAt = DateTime.parse(d['registered_at']);
            return regAt.isAfter(DateTime.parse(startOfWeekStr)) || 
                  regAt.isAtSameMomentAs(DateTime.parse(startOfWeekStr));
          }).length;

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Dashboard Refresh Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', widget.userId);
    await prefs.setString('userType', widget.userType);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 1100;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 50 : 20, 
            vertical: 30
          ),
          child: _buildMainLayout(context, screenWidth, isDesktop),
        ),
      ),
    );
  }

  Widget _buildMainLayout(BuildContext context, double screenWidth, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 100 : 25, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            children: [
              Center(
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF0A4539),
                      Color(0xFF4D9145),
                      Color(0xFF92BC36),
                      Color(0xFF569743),
                      Color(0xFF185A3B)
                    ],
                  ).createShader(Offset.zero & bounds.size),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Welcome, $displayName!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 75 : 35,
                        fontFamily: 'Noto Sans Hebrew',
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Easily track and monitor your activities below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w200,
                  fontFamily: 'Noto Sans Hebrew',
                ),
              ),
            ],
          ),

          const SizedBox(height: 60),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: screenWidth > 1100 ? 3 : (screenWidth > 750 ? 2 : 1),
            mainAxisSpacing: 50,
            crossAxisSpacing: 50,
            childAspectRatio: isDesktop ? 1.1 : 0.95,
            children: [
              _DashboardCard(
                title: 'REGISTERED DOCUMENT THIS WEEK',
                count: weeklyCount,
                description: 'The number of all documents officially filed and validated within the current week from this account.',
                isDesktop: isDesktop,
              ),
              _DashboardCard(
                title: 'TOTAL REGISTERED DOCUMENTS',
                count: totalCount,
                description: 'The overall count of all documents successfully processed and stored in the system to date from this account.',
                opacity: 0.07,
                isDesktop: isDesktop,
              ),
              _DashboardCard(
                title: 'TOTAL # OF DOCUMENTS RECEIVED BACK',
                count: receivedCount,
                description: 'Total number of files successfully processed and returned to this account after external review or action.',
                isDesktop: isDesktop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// DASHBOARD CARD WIDGET
class _DashboardCard extends StatelessWidget {
  final String title;
  final String description;
  final double opacity;
  final int count;
  final bool isDesktop;

  const _DashboardCard({
    required this.title, 
    required this.description, 
    required this.count,
    required this.isDesktop,
    this.opacity = 0.10
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 25 : 15), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE6AD3E), width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              color: Colors.white, 
              fontSize: isDesktop ? 20 : 14, 
              fontFamily: 'Inter', 
              fontWeight: FontWeight.bold,
              height: 1.2
            ),
          ),
          
          SizedBox(height: isDesktop ? 15 : 8),
          
          Text(
            count.toString(),
            style: TextStyle(
              color: const Color(0xFF78CF4E), 
              fontSize: isDesktop ? 55 : 32, 
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          
          SizedBox(height: isDesktop ? 15 : 8),
          
          Text(
            description,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              color: Colors.white70, 
              fontSize: isDesktop ? 13 : 11, 
              fontFamily: 'Noto Sans Hebrew', 
              fontWeight: FontWeight.w200,
              height: 1.4
            ),
          ),
        ],
      ),
    );
  }
}