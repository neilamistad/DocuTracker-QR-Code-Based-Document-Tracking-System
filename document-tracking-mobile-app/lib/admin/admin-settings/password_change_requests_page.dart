import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/admin_notifications.dart';
import '../../utils/password_update_email_service.dart';

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
    if (_realtimeChannelPasswordRequests != null) supabase.removeChannel(_realtimeChannelPasswordRequests!);
    super.dispose();
  }

  // LOGIC: REALTIME & ACTIONS
  void _setupRealtime() {
    _realtimeChannelPasswordRequests = supabase.channel('public:password_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'password_requests',
      callback: (payload) => fetchResetRequests(),
    ).subscribe();
  }

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

  Future<void> _handleAction(Map<String, dynamic> request, bool isApprove) async {
    setState(() => isProcessing = true);
    final String id = request['id'].toString();
    final String emailOrUser = request['email_or_username'].toString();
    final String userType = request['user_type'].toString();

    try {
      if (isApprove) {
        String targetTable = userType.toLowerCase() == 'faculty' ? 'faculty_accounts' : 'student_org_accounts';
        String emailColumn = userType.toLowerCase() == 'faculty' ? 'cvsu_email' : 'email';
        
        await supabase.from(targetTable).update({
          'password_hash': request['new_password']
        }).eq(emailColumn, emailOrUser);
        
      }

      await supabase.from('password_requests').update({
        'status': isApprove ? 'approved' : 'rejected',
        'is_read_admin': true,
        'is_read_user': false
      }).eq('id', id);

      await PasswordUpdateEmailService.sendPasswordStatusEmail(
        email: emailOrUser,
        status: isApprove ? 'APPROVED' : 'REJECTED',
      );

      if (mounted) {
        _showTopNotification(
          isApprove ? "Password updated for $emailOrUser" : "Request rejected for $emailOrUser",
          isApprove ? const Color(0xFF78CF4E) : Colors.orangeAccent
        );
        fetchResetRequests();
      }
    } catch (e) {
      if (mounted) _showTopNotification("Action failed: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => isProcessing = false);
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

  // UI BUILDING
  @override
  Widget build(BuildContext context) {
    final filteredData = allRequests.where((req) {
      final query = searchCtrl.text.toLowerCase();

      final email = (req['email_or_username'] ?? '').toString().toLowerCase();
      final userId = (req['user_id'] ?? '').toString().toLowerCase();

      return email.contains(query) || userId.contains(query);
    }).toList();

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
                  : _buildList(filteredData),
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
          Text("Password Requests", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        adminDeletionRequestNotifier,
        adminQRReprintNotifier,
        adminFacultyRequestNotifier,
      ]),
      builder: (context, _) {
        final bool hasNotif = adminDeletionRequestNotifier.value > 0 || 
                             adminQRReprintNotifier.value > 0 || 
                             adminFacultyRequestNotifier.value > 0;
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
                right: -2, top: -2,
                child: Container(
                  width: 12, height: 12,
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
            onChanged: (v) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "Search Username, Email or ID...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Symbols.search, color: Color(0xFF78CF4E), size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
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

    return RefreshIndicator(
      onRefresh: fetchResetRequests,
      color: const Color(0xFF78CF4E),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
        itemCount: data.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildResetCard(data[index]),
      ),
    );
  }

  Widget _buildResetCard(Map<String, dynamic> req) {
    final bool isUnread = req['is_read_admin'] == false;
   
    final DateTime? dt = DateTime.tryParse(req['created_at'] ?? "");
    String displayDateTime = "---- --, ---- | --:--:-- --";
    
    if (dt != null) {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      String month = months[dt.month - 1];
      String day = dt.day.toString().padLeft(2, '0');
      int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      String min = dt.minute.toString().padLeft(2, '0');
      String sec = dt.second.toString().padLeft(2, '0');
      String amPm = dt.hour >= 12 ? "PM" : "AM";
      
      displayDateTime = "$month $day, ${dt.year} | ${hour.toString().padLeft(2, '0')}:$min:$sec $amPm";
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ?  Colors.white.withOpacity(0.3) : Colors.white10,
                  width: isUnread ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                          displayDateTime, 
                          style: const TextStyle(color: Colors.white24, fontSize: 10)
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      req['email_or_username'], 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                    const Text(
                      "Requested a password reset", 
                      style: TextStyle(color: Colors.white38, fontSize: 13)
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            "Reject", 
                            Colors.redAccent.withOpacity(0.1), 
                            Colors.redAccent, 
                            () => _handleAction(req, false)
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionButton(
                            "Approve", 
                            const Color(0xFF78CF4E).withOpacity(0.1), 
                            const Color(0xFF78CF4E), 
                            () => _handleAction(req, true)
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        if (isUnread)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF121212), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
      ],
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
          Icon(isSearching ? Symbols.search_off : Symbols.lock_reset, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(isSearching ? "No matching requests" : "No pending reset requests", 
              style: const TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }
}