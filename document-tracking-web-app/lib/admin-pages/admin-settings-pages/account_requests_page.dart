import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/app_background.dart';

import '../../utils/account_approval_email_service.dart';
import '../../utils/admin_notification_utils.dart'; 

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

  // LOGIC: REALTIME LISTENER
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

  // LOGIC: FETCH & NOTIFICATION MARKER
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
      debugPrint('Error fetching requests: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // LOGIC: ACTION HANDLER (Approve/Reject)
  Future<void> _handleAction(Map<String, dynamic> request, bool isApprove) async {
    setState(() => isProcessing = true);
    final facultyId = request['faculty_id'];
    final email = request['cvsu_email'];

    try {
      if (isApprove) {

        await supabase.from('faculty_accounts').insert({
          'faculty_id': facultyId,
          'cvsu_email': email,
          'first_name' : request['first_name'],
          'last_name' : request['last_name'],
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

        _showTopNotification(isApprove ? 'Account approved for $email' : 'Request rejected', isApprove ? Colors.green : Colors.red);
        
        fetchRequests();
      }
    } catch (e) {
      debugPrint("Action Error: $e");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showConfirmDialog(Map<String, dynamic> request, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: Text(isApprove ? "Confirm Approval" : "Reject Request", style: const TextStyle(color: Colors.white)),
        content: Text(
          isApprove 
            ? "Create account for ${request['cvsu_email']}?" 
            : "Deny application for ${request['faculty_id']}?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? const Color(0xFF78CF4E) : Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _handleAction(request, isApprove);
            },
            child: Text(isApprove ? "Approve" : "Reject", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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

  //  UI BUILDING
  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredRequests();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchBar(),
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

  Widget _buildRequestList(List<Map<String, dynamic>> filteredData) {
    if (filteredData.isEmpty) {
      return _buildEmptyState(isSearching: searchCtrl.text.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: fetchRequests,
      color: const Color(0xFF78CF4E),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filteredData.length,
        separatorBuilder: (_, _) => const SizedBox(height: 15),
        itemBuilder: (context, index) => _buildRequestCard(filteredData[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    bool isUnread = req['is_read_admin'] == false;

    final DateTime? dt = DateTime.tryParse(req['created_at'] ?? "");

    String displayTime = "--:--";
    String displayDate = "----/--/--";

    if (dt != null) {

      final int hour = dt.hour;
      final String amPm = hour >= 12 ? "PM" : "AM";
      final int hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final String minute = dt.minute.toString().padLeft(2, '0');
      
      displayTime = "$hour12:$minute $amPm";
      

      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      displayDate = "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnread ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.1),
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Badge(
                      isLabelVisible: isUnread,
                      backgroundColor: Colors.redAccent,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF78CF4E).withOpacity(0.2),
                        child: const Icon(Symbols.person, color: Color(0xFF78CF4E)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['cvsu_email'], 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis),
                          Text("ID: ${req['faculty_id']}", 
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 25),
                _infoRow(Symbols.school, "Course: ${req['course']}"),
                _infoRow(Symbols.history, "Requested: $displayDate | $displayTime"),
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

  // UTILS & WIDGETS
  List<Map<String, dynamic>> _getFilteredRequests() {
    final query = searchCtrl.text.toLowerCase();
    if (query.isEmpty) return requests;
    return requests.where((req) {
      final email = (req['cvsu_email'] ?? '').toString().toLowerCase();
      final id = (req['faculty_id'] ?? '').toString().toLowerCase();
      return email.contains(query) || id.contains(query);
    }).toList();
  }

  Widget _buildHeader(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              adminPasswordRequestNotifier,
              adminDeletionRequestNotifier,
              adminQRReprintNotifier,
            ]),
            builder: (context, child) {
              final bool hasNotification = (adminPasswordRequestNotifier.value > 0) || 
                                          (adminDeletionRequestNotifier.value > 0) || 
                                          (adminQRReprintNotifier.value > 0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                  
                  if (hasNotification)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          Text("Account Requests", style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: TextField(
            controller: searchCtrl,
            onChanged: (value) => setState(() {}),
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "Search Email or ID...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF78CF4E)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  Widget _actionButton(String label, Color bg, Color border, VoidCallback onTap) => InkWell(
    onTap: isProcessing ? null : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: border, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildEmptyState({bool isSearching = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSearching ? Symbols.search_off : Symbols.person_add_disabled, size: 60, color: Colors.white24),
          const SizedBox(height: 15),
          Text(isSearching ? "No matching accounts" : "No pending accounts", style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}