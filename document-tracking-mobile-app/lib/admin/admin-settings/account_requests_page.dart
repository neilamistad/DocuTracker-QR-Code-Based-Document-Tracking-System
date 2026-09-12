import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/admin_notifications.dart';
import '../../utils/account_approval_email_service.dart';

class AccountRequestsPage extends StatefulWidget {
  const AccountRequestsPage({super.key});

  @override
  State<AccountRequestsPage> createState() => _AccountRequestsPageState();
}

class _AccountRequestsPageState extends State<AccountRequestsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  bool isProcessing = false;
  RealtimeChannel? _accountChannel;

  @override
  void initState() {
    super.initState();
    fetchRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_accountChannel != null) supabase.removeChannel(_accountChannel!);
    searchCtrl.dispose();
    super.dispose();
  }

  //  LOGIC: REALTIME & FETCH
  void _setupRealtime() {
    _accountChannel = supabase
        .channel('public:faculty_account_registration_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'faculty_account_registration_requests',
          callback: (payload) => fetchRequests(),
        )
        .subscribe();
  }

  Future<void> fetchRequests() async {
    try {
      final data = await supabase
          .from('faculty_account_registration_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          requests = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleAction(Map<String, dynamic> request, bool isApprove) async {
    setState(() => isProcessing = true);
    final facultyId = request['faculty_id'];
    final email = request['cvsu_email'];

    try {
      if (isApprove) {
        await supabase.from('faculty_accounts').insert({
          'faculty_id': facultyId,
          'cvsu_email': email,
          'first_name': request['first_name'],
          'last_name': request['last_name'],
          'course': request['course'],
          'password_hash': request['password_hash'],
        });
        try {
          await AccountApprovalEmailService.sendAccountApprovalEmail(
            email: email,
            firstName: request['first_name'] ?? 'Faculty',
            facultyId: facultyId,
          );
        } catch (emailError) {
          debugPrint("Non-critical Email Error: $emailError");
        }
      }

      await supabase
          .from('faculty_account_registration_requests')
          .update({
            'status': isApprove ? 'approved' : 'rejected',
            'is_read_admin': true,
          })
          .eq('faculty_id', facultyId);

      if (mounted) {
        await AdminNotificationUtils.syncAdminBadgeCounts();
        _showTopNotification(isApprove ? 'Account approved' : 'Request rejected', 
            isApprove ? const Color(0xFF78CF4E) : Colors.redAccent);
        fetchRequests();
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // REUSABLE UTILS
  List<Map<String, dynamic>> _getFilteredRequests() {
    final q = searchCtrl.text.toLowerCase();
    if (q.isEmpty) return requests;
    return requests.where((r) => 
      r['cvsu_email'].toString().toLowerCase().contains(q) || 
      r['faculty_id'].toString().toLowerCase().contains(q) ||
      "${r['first_name']} ${r['last_name']}".toLowerCase().contains(q)
    ).toList();
  }

  void _showConfirmDialog(Map<String, dynamic> request, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
          title: Text(isApprove ? "Confirm Approval" : "Reject Request", style: const TextStyle(color: Colors.white, fontSize: 18)),
          content: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              children: [
                TextSpan(
                  text: "Are you sure you want to ${isApprove ? 'approve' : 'reject'} the account for Faculty ID: ",
                ),
                TextSpan(
                  text: "${request['faculty_id']}?",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? const Color(0xFF78CF4E) : Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () { Navigator.pop(context); _handleAction(request, isApprove); },
              child: Text(isApprove ? "Approve" : "Reject", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return "Unknown Date";
    
    try {
      DateTime dt = DateTime.parse(raw);

      const months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      String month = months[dt.month - 1];

      int hour = dt.hour;
      String period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour;

      String minute = dt.minute.toString().padLeft(2, '0');
      String second = dt.second.toString().padLeft(2, '0');
      String day = dt.day.toString().padLeft(2, '0');

      return "$month $day, ${dt.year} | ${hour.toString().padLeft(2, '0')}:$minute:$second $period";
      
    } catch (e) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }

  // UI BUILDING
  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredRequests();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchSection(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                    : _buildRequestList(filteredData),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 20, 10),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 10),
          Text("Account Requests", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        adminPasswordRequestNotifier,
        adminDeletionRequestNotifier,
        adminQRReprintNotifier,
      ]),
      builder: (context, _) {
        final bool hasNotif = (adminPasswordRequestNotifier.value > 0) ||
                             (adminDeletionRequestNotifier.value > 0) ||
                             (adminQRReprintNotifier.value > 0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
            if (hasNotif)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "Search Name, CvSU Email or Faculty ID...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Symbols.search, color: Color(0xFF78CF4E), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> filteredData) {
    if (filteredData.isEmpty) {
      return _buildEmptyState(isSearching: searchCtrl.text.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: fetchRequests,
      color: const Color(0xFF78CF4E),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
        itemCount: filteredData.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildRequestCard(filteredData[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    bool isUnread = req['is_read_admin'] == false;
    final String fullName = "${req['first_name']} ${req['last_name']}";
    final status = req['status'] ?? 'pending';

    Color color = status == 'approved' ? const Color(0xFF78CF4E) : (status == 'rejected' ? Colors.redAccent : Colors.orangeAccent);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: isUnread ? Colors.orangeAccent.withOpacity(0.05) : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnread ? Colors.orangeAccent.withOpacity(0.3) : color.withOpacity(0.3),
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF78CF4E).withOpacity(0.1),
                      child: const Icon(Symbols.person_filled, color: Color(0xFF78CF4E), size: 24),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName, 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(req['cvsu_email'], 
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                        child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _infoRow(Symbols.badge, "Faculty ID: ", req['faculty_id']),
                _infoRow(Symbols.school, "Course: ", req['course']),
                _infoRow(
                  Symbols.calendar_today, 
                  "Requested at: ", 
                  _formatDateTime(req['created_at']),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _actionButton("Reject", Colors.redAccent.withOpacity(0.1), Colors.redAccent, () => _showConfirmDialog(req, false))),
                    const SizedBox(width: 12),
                    Expanded(child: _actionButton("Approve", const Color(0xFF78CF4E).withOpacity(0.1), const Color(0xFF78CF4E), () => _showConfirmDialog(req, true))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white24),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color bg, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSearching = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSearching ? Symbols.search_off : Symbols.person_add, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(isSearching ? "No matching requests found" : "No pending account requests", 
              style: const TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }
}