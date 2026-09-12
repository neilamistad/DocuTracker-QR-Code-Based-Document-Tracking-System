import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/background_wrapper.dart';

import '../full_tracking_history_page.dart';

class UserDashboardPage extends StatefulWidget {
  final String userId;
  final String userType;

  const UserDashboardPage({super.key, required this.userId, required this.userType});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _dashboardStream;
  String greetingName = "User";

  @override
  void initState() {
    super.initState();
    _fetchUserDisplayName();

    _dashboardStream = Supabase.instance.client
        .from('tracking_history')
        .stream(primaryKey: ['history_id'])
        .eq('registered_by_id', widget.userId)
        .order('updated_at', ascending: false)
        .startWith([]);
  }

  Future<void> _fetchUserDisplayName() async {
    try {
      final table = widget.userType.toLowerCase() == 'faculty' 
          ? 'faculty_accounts' 
          : 'student_org_accounts';
      
      final idColumn = widget.userType.toLowerCase() == 'faculty' 
          ? 'faculty_id'
          : 'org_id';

      final data = await Supabase.instance.client
          .from(table)
          .select()
          .eq(idColumn, widget.userId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          greetingName = widget.userType.toLowerCase() == 'faculty'
              ? data['first_name'] ?? "Faculty"
              : data['org_name'] ?? "Organization";
        });
      }
    } catch (e) {
      _showTopNotification("FETCH_NAME_ERROR: $e", Colors.red);
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
    return BackgroundWrapper(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dashboardStream,
        builder: (context, snapshot) {
          int onTheProcessDocs = 0;
          int receivedBackDocs = 0;
          List<Map<String, dynamic>> recentActivities = [];

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8BB839)));
          }

          if (snapshot.hasData) {
            final Map<String, Map<String, dynamic>> uniqueDocs = {};
            
            for (var row in snapshot.data!) {
              final docId = row['tracking_id']?.toString() ?? row['document_id'].toString();
              if (!uniqueDocs.containsKey(docId)) {
                uniqueDocs[docId] = row;
              }
            }

            final allLatestUpdates = uniqueDocs.values.toList();
            
            onTheProcessDocs = allLatestUpdates.where((doc) => doc['status'] != 'Received Back').length;
            receivedBackDocs = allLatestUpdates.where((doc) => doc['status'] == 'Received Back').length;

            recentActivities = allLatestUpdates.take(3).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 70, 25, 100), 
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserGreetingHeader(),

                const SizedBox(height: 35),

                const Text("Documents Quick Overview", 
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.1)),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    _buildStatCard("On Process", "$onTheProcessDocs", Colors.orangeAccent),
                    const SizedBox(width: 15),
                    _buildStatCard("Received Back", "$receivedBackDocs", Colors.green),
                  ],
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Recent Tracking History", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 20),
                  ],
                ),
                const SizedBox(height: 25),
                
                if (recentActivities.isEmpty)
                  _buildEmptyActivity()
                else
                  ...recentActivities.map((activity) => _buildTimelineItem(
                    activity['tracking_id'] ?? activity['document_id'] ?? 'Unknown Document',
                    activity['status'] ?? 'Pending',
                    activity['updated_at'] ?? '',
                    activity,
                  )),
              ],
            ),
          );
        },
      ),
    );
  }
  

  Widget _buildStatCard(String title, String count, Color accent) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count, 
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 36, 
                    fontFamily: 'Noto Sans Hebrew',
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  title, 
                  style: TextStyle(
                    color: accent, 
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, String status, String timestamp, Map<String, dynamic> activity) {
    String timeFormatted = "---";

    if (timestamp.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(timestamp);
        timeFormatted = DateFormat('MMM dd, yyyy | hh:mm:ss a').format(dt).toUpperCase();
      } catch (e) {
        debugPrint("TIME_ERROR: $e");
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
            ),
          );

          try {
            final String docId = activity['document_id']?.toString() ?? '';

            final docSnapshot = await supabase
                .from('documents')
                .select()
                .eq('document_id', docId)
                .maybeSingle();

            final historyResponse = await supabase
                .from('tracking_history')
                .select()
                .eq('document_id', docId)
                .order('updated_at', ascending: true);

            if (context.mounted) Navigator.pop(context);

            if (context.mounted && docSnapshot != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullTrackingHistoryPage(
                    history: List<Map<String, dynamic>>.from(historyResponse),
                    document: docSnapshot,
                  ),
                ),
              );
            } else {
              _showTopNotification("Document details not found.", Colors.orange);
            }
          } catch (e) {
            if (context.mounted) Navigator.pop(context);
            _showTopNotification("Error: $e", Colors.red);
          }
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 12, color: Color(0xFF8BB839)),
                  Container(width: 1, height: 45, color: Colors.white10),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: const TextStyle(color: Color(0xFF8BB839), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeFormatted,
                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Inter', letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGreetingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF008174), Color(0xFF92BC36), Color(0xFF00984F)],
            ).createShader(Offset.zero & bounds.size),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                "Greetings, $greetingName!", 
                style: const TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w800, 
                  fontFamily: 'Noto Sans Hebrew'
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),

        // USER TYPE BADGE
        Container(
          margin: const EdgeInsets.only(top: 2, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF78CF4E).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF78CF4E).withOpacity(0.2), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.userType.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF78CF4E),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.pin_drop_rounded, color: Colors.white.withOpacity(0.05), size: 80),
          const SizedBox(height: 5),
          const Text("No recent updates found", style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}