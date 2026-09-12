
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../widgets/background_wrapper.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final supabase = Supabase.instance.client;

  // STREAMS
  late final Stream<List<Map<String, dynamic>>> _allDocumentsStream;
  late final Stream<List<Map<String, dynamic>>> _facultyAccountsStream;

  @override
  void initState() {
    super.initState();
    
    _allDocumentsStream = supabase
        .from('documents')
        .stream(primaryKey: ['document_id'])
        .startWith([]);

    _facultyAccountsStream = supabase
        .from('faculty_accounts')
        .stream(primaryKey: ['faculty_id'])
        .order('created_at', ascending: false)
        .startWith([]);
  }

  String get adminUsername {
    final user = supabase.auth.currentUser;
    return user?.userMetadata?['username'] ?? 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: StreamBuilder(
        stream: Rx.combineLatest2(
          _allDocumentsStream,
          _facultyAccountsStream,
          (List<Map<String, dynamic>> docs, List<Map<String, dynamic>> faculty) => {
            'docs': docs,
            'faculty': faculty,
          },
        ),
        builder: (context, AsyncSnapshot<Map<String, List<Map<String, dynamic>>>> snapshot) {
          int onProcessDocs = 0;
          int receivedBackDocs = 0;
          List<Map<String, dynamic>> recentApprovedFaculty = [];

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8BB839)));
          }

          if (snapshot.hasData) {
            final allDocs = snapshot.data?['docs'] ?? [];
            final allFaculty = snapshot.data?['faculty'] ?? [];

            onProcessDocs = allDocs.where((doc) => doc['status'] != 'Received Back').length;
            receivedBackDocs = allDocs.where((doc) => doc['status'] == 'Received Back').length;

            recentApprovedFaculty = allFaculty.take(5).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 50, 25, 100),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdminHeader(),
                const SizedBox(height: 35),

                const Text("System-wide Document Overview", 
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.1)),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    _buildStatCard("On Process", "$onProcessDocs", Colors.orangeAccent),
                    const SizedBox(width: 15),
                    _buildStatCard("Received Back", "$receivedBackDocs", Colors.green),
                  ],
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Recently Approved Faculty", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 25),
                
                if (recentApprovedFaculty.isEmpty)
                  _buildEmptyActivity()
                else
                  ...recentApprovedFaculty.map((faculty) => _buildFacultyItem(
                    "${faculty['first_name']} ${faculty['last_name']}",
                    faculty['cvsu_email'] ?? 'No Email',
                    faculty['created_at'] ?? '',
                  )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminHeader() {
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
              padding: const EdgeInsets.symmetric(vertical: 20), 
              child: Text(
                "Greetings, $adminUsername!",
                style: const TextStyle(
                  fontSize: 30, 
                  fontWeight: FontWeight.w800, 
                  fontFamily: 'Noto Sans Hebrew', 
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
        const Text(
          "CvSU-CCAT Document Tracking System", 
          style: TextStyle(color: Colors.white38, fontSize: 12),
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
            Text(count, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Hebrew')),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyItem(String name, String email, String date) {
    String timeFormatted = "---";
    if (date.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(date);
        timeFormatted = DateFormat('MMM dd, yyyy\nhh:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF8BB839).withOpacity(0.2),
            child: const Icon(Icons.school_rounded, color: Color(0xFF8BB839), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    name, 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 15, 
                      fontWeight: FontWeight.bold
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    email, 
                    style: const TextStyle(
                      color: Colors.white38, 
                      fontSize: 12
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            timeFormatted, 
            textAlign: TextAlign.right, 
            style: const TextStyle(
              color: Colors.white24, 
              fontSize: 10,
              height: 1.2
            )
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return const Center(child: Text("No recently approved accounts.", style: TextStyle(color: Colors.white24)));
  }
}