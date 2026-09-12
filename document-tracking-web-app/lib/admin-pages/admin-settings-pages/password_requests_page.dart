import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../utils/admin_notification_utils.dart';
import '../../utils/password_update_email_service.dart';

import '../../widgets/app_background.dart';

class PasswordResetRequestsPage extends StatefulWidget {
  const PasswordResetRequestsPage({super.key});

  @override
  State<PasswordResetRequestsPage> createState() => _PasswordResetRequestsPageState();
}

class _PasswordResetRequestsPageState extends State<PasswordResetRequestsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchCtrl = TextEditingController();
  
  List<Map<String, dynamic>> allRequests = [];
  bool isLoading = true;
  bool isProcessing = false;

  RealtimeChannel? _realtimeChannelPasswordRequests;

  @override
  void initState() {
    super.initState();
    fetchResetRequests();
    _setupRealtime();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
    if (_realtimeChannelPasswordRequests != null) supabase.removeChannel(_realtimeChannelPasswordRequests!);
  }

  void _setupRealtime() {
    _realtimeChannelPasswordRequests = supabase.channel('public:password_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'password_requests',
      callback: (payload) {
        fetchResetRequests();
      },
    ).subscribe();
  }

  Future<void> _handleReject(dynamic id, String email) async {
    setState(() => isProcessing = true);
    try {
      await supabase
          .from('password_requests')
          .update({'status': 'rejected', 'is_read_admin': true, 'is_read_user': false})
          .eq('id', id.toString());
      
      await PasswordUpdateEmailService.sendPasswordStatusEmail(email: email, status: 'REJECTED');

      if (mounted) {
        _showTopNotification("Password reset for $email has been rejected.", Colors.orange);
        fetchResetRequests();
      }

      if (mounted) {
        // ADDED SNACKBAR FOR REJECTED
        _showTopNotification("Password reset for $email has been rejected.", Colors.orange);

        fetchResetRequests();
      }
    } catch (e) {
      if (mounted) {
        _showTopNotification("Error rejecting request: $e", Colors.red);

      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // LOGIC: FETCH DATA
  Future<void> fetchResetRequests() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final data = await supabase
          .from('password_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() {
        allRequests = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // LOGIC: APPROVAL FLOW
  Future<void> _handleApproval(Map<String, dynamic> request) async {
    setState(() => isProcessing = true);
    final String userType = request['user_type'].toString();
    final String emailOrUser = request['email_or_username'].toString();
    final String newHash = request['new_password'].toString();

    try {
      String targetTable = userType.toLowerCase() == 'faculty' ? 'faculty_accounts' : 'student_org_accounts';
      String emailColumn = userType.toLowerCase() == 'faculty' ? 'cvsu_email' : 'email';

      await supabase.from(targetTable).update({'password_hash': newHash}).eq(emailColumn, emailOrUser);
      await supabase.from('password_requests').update({'status': 'approved', 'is_read_admin': true, 'is_read_user': false}).eq('id', request['id']);

      await PasswordUpdateEmailService.sendPasswordStatusEmail(
        email: emailOrUser, 
        status: 'APPROVED',
      );
      
      if (mounted) {
        _showTopNotification("Password updated for $emailOrUser", Colors.green);
        fetchResetRequests();
      }
    } catch (e) {
      if (mounted) _showTopNotification("Approval failed: $e", Colors.red);

    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // UI COMPONENTS

  @override
  Widget build(BuildContext context) {
    final filteredData = allRequests.where((req) {
      final query = searchCtrl.text.toLowerCase();
      return req['email_or_username'].toString().toLowerCase().contains(query) ||
             req['user_id'].toString().toLowerCase().contains(query);
    }).toList();

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
                  : _buildList(filteredData),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext text) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              adminDeletionRequestNotifier,
              adminQRReprintNotifier,
              adminFacultyRequestNotifier,
            ]),
            builder: (context, child) {

              final bool hasNotification = (adminDeletionRequestNotifier.value > 0) || 
                                          (adminQRReprintNotifier.value > 0) || 
                                          (adminFacultyRequestNotifier.value > 0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                  
                  // RED DOT BADGE
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
                          border: Border.all(color:  Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Text(
                "Password Reset/Change Requests", 
                style: TextStyle(
                  fontSize: isMobile ? 18 : 24, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                ),
              ),
            ),
          ),
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
            onChanged: (v) => setState(() {}),
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromARGB(255, 255, 192, 192).withOpacity(0.05),
              hintText: "Search Username, Email, or User ID...",
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

  Widget _buildList(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyState(isSearching: searchCtrl.text.isNotEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: data.length,
      separatorBuilder: (_, _) => const SizedBox(height: 15),
      itemBuilder: (context, index) => _buildResetCard(data[index], context),
    );
  }

  Widget _buildResetCard(Map<String, dynamic> req, BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    final bool isUnread = req['is_read_admin'] == false;

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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ID: ${req['user_id'] ?? 'N/A'}", 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12,
                          letterSpacing: 0.5
                        )
                      ),
                      Text(
                        "$displayDate • $displayTime",
                        style: TextStyle(color: Colors.white38, fontSize: isMobile ? 11 : 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(req['email_or_username'], 
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("Requested a password change", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const Divider(color: Colors.white10, height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          "Reject", 
                          Colors.orangeAccent.withOpacity(0.1), 
                          Colors.orangeAccent, 
                          () => _handleReject(req['id'], req['email_or_username'] ?? 'User'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          "Approve", 
                          const Color(0xFF78CF4E).withOpacity(0.1), 
                          const Color(0xFF78CF4E), 
                          () => _handleApproval(req)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // RED DOT BADGE
        if (isUnread)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }

  // HELPERS

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
          Icon(isSearching ? Symbols.search_off : Symbols.lock_open, size: 80, color: Colors.white24),
          const SizedBox(height: 15),
          Text(isSearching ? "No matching reset requests" : "No pending reset requests", 
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
}