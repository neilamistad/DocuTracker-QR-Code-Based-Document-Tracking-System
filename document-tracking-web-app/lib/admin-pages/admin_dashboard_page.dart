import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/admin_notification_utils.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  int totalDocs = 0;
  int totalReceived = 0;
  int facultyCount = 0;
  int orgCount = 0;
  int officeCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    
    AdminNotificationUtils.syncAdminBadgeCounts();
    AdminNotificationUtils.initializeAdminListeners();

    _setupRealtimeStats();
  }

  // REAL-TIME LOGIC
  void _setupRealtimeStats() async {
    await _fetchAllStats();

    supabase
        .channel('public:documents')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
          callback: (payload) => _fetchAllStats(),
        )
        .subscribe();

    final accountTables = [
      'faculty_accounts',
      'student_org_accounts',
      'other_office_accounts'
    ];

    for (var table in accountTables) {
      supabase
          .channel('public:$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (payload) => _fetchAllStats(),
          )
          .subscribe();
    }
  }

  Future<void> _fetchAllStats() async {
    try {
      final results = await Future.wait([
        supabase.from('documents').select('document_id, current_status'),
        supabase.from('faculty_accounts').select('faculty_id'),
        supabase.from('student_org_accounts').select('org_id'),
        supabase.from('other_office_accounts').select('office_id'),
      ]);

      if (mounted) {
        setState(() {
          final docs = results[0] as List;
          totalDocs = docs.length;
          totalReceived = docs.where((d) => d['current_status'] == 'Received Back').length;
          
          facultyCount = (results[1] as List).length;
          orgCount = (results[2] as List).length;
          officeCount = (results[3] as List).length;
          
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Realtime Stats Error: $e");
    }
  }

  // LOGIC: COUNTING FOR ADMIN SIDE
  Future<Map<String, dynamic>> fetchAdminStats() async {
    try {
      // A. TOTAL REGISTERED DOCUMENTS
      final totalDocsRes = await supabase.from('documents').select('document_id');

      // B. ACCOUNTS BREAKDOWN
      final facultyRes = await supabase.from('faculty_accounts').select('faculty_id');
      final orgRes = await supabase.from('student_org_accounts').select('org_id');
      final officeRes = await supabase.from('other_office_accounts').select('office_id');

      int fCount = (facultyRes as List).length;
      int orgCount = (orgRes as List).length;
      int offCount = (officeRes as List).length;

      // C. TOTAL RECIEVED DOCUMENTS
      final totalReceivedRes = await supabase
          .from('documents')
          .select('document_id')
          .eq('current_status', 'received');

      return {
        'totalDocs': (totalDocsRes as List).length,
        'approvedUsers': fCount + orgCount + offCount,
        'totalReceived': (totalReceivedRes as List).length,
        'breakdown': "Faculty: $fCount\nOrganizations: $orgCount\nOffices: $offCount",
      };
    } catch (e) {
      debugPrint("Admin Stats Error: $e");
      return {
        'totalDocs': 0,
        'approvedUsers': 0,
        'totalReceived': 0,
        'breakdown': "Data unavailable",
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
      );
    }

    final stats = {
      'totalDocs': totalDocs,
      'approvedUsers': facultyCount + orgCount + officeCount,
      'totalReceived': totalReceived,
      'breakdown': "Faculty: $facultyCount\nOrganizations: $orgCount\nOffices: $officeCount",
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 1000;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60 : 25,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildGreetings(constraints.maxWidth),
              const SizedBox(height: 60),
              _buildStatsGrid(stats, constraints.maxWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetings(double width) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF0A4539),
              Color(0xFF4D9145),
              Color(0xFF92BC36),
              Color(0xFF569743),
              Color(0xFF185A3B),
            ],
          ).createShader(Offset.zero & bounds.size),
          child: Text(
            'Greetings, Admin!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: width > 600 ? 70 : 35,
              fontFamily: 'Noto Sans Hebrew',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Monitor and manage system-wide document operations',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Noto Sans Hebrew',
            fontWeight: FontWeight.w200,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats, double width) {
    int crossAxisCount = width > 1100 ? 3 : (width > 700 ? 2 : 1);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 30,
      crossAxisSpacing: 30,
      childAspectRatio: width > 1100 ? 1.2 : 1.0,
      children: [
        _DashboardCard(
          title: 'TOTAL REGISTERED DOCUMENTS',
          count: stats['totalDocs'],
          description: 'Overall count of all documents successfully indexed.',
        ),
        Tooltip(
          message: stats['breakdown'],
          padding: const EdgeInsets.all(15),
          textStyle: const TextStyle(
            color: Colors.white, 
            fontSize: 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A4539).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF78CF4E)),
          ),
          child: _DashboardCard(
            title: 'TOTAL APPROVED ACCOUNTS',
            count: stats['approvedUsers'],
            description: 'Total verified accounts across all categories.',
            opacity: 0.08,
          ),
        ),
        _DashboardCard(
          title: 'TOTAL DOCUMENTS RECEIVED BACK',
          count: stats['totalReceived'],
          description: 'Total number of documents processed and received back by the users/owners.',
        ),
      ],
    );
  }
}

// DASHBOARD CARD WIDGET
class _DashboardCard extends StatelessWidget {
  final String title;
  final String description;
  final double opacity;
  final int count;

  const _DashboardCard({
    required this.title, 
    required this.description, 
    required this.count, 
    this.opacity = 0.10
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE6AD3E), width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 20, 
                fontFamily: 'Inter', 
                fontWeight: FontWeight.bold,
                height: 1.2
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Color(0xFF78CF4E), 
              fontSize: 55, 
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 15),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70, 
              fontSize: 13, 
              fontFamily: 'Noto Sans Hebrew', 
              fontWeight: FontWeight.w200,
              height: 1.5
            ),
          ),
        ],
      ),
    );
  }
}