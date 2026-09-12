import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/admin_notifications.dart';

class QRReprintRequestsPage extends StatefulWidget {
  const QRReprintRequestsPage({super.key});

  @override
  State<QRReprintRequestsPage> createState() => _QRReprintRequestsPageState();
}

class _QRReprintRequestsPageState extends State<QRReprintRequestsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> allRequests = [];
  bool isLoading = true;
  bool isProcessing = false;

  RealtimeChannel? _reprintChannel;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_reprintChannel != null) supabase.removeChannel(_reprintChannel!);
    searchCtrl.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _reprintChannel = supabase.channel('public:qr_reprint_requests').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'qr_reprint_requests',
      callback: (payload) => _refreshData(),
    ).subscribe();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final res = await supabase
          .from('qr_reprint_requests')
          .select()
          .order('requested_at', ascending: false);
      
      if (mounted) {
        setState(() {
          allRequests = List<Map<String, dynamic>>.from(res);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleAction(String requestId, String status, String message) async {
    setState(() => isProcessing = true);
    try {

      await supabase.from('qr_reprint_requests').update({
        'status': status,
        'is_read_admin': true,
        'is_read_user': false
      }).eq('id', requestId);

      if (mounted) {
        await AdminNotificationUtils.syncAdminBadgeCounts();
        _showTopNotification(message, status == 'approved' ? const Color(0xFF78CF4E) : Colors.redAccent);
        _refreshData();
      }
    } catch (e) {
      if (mounted) _showTopNotification("Error: $e", Colors.redAccent);
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

  // DIALOGS (ACTION & DETAILS)
  void _showActionDialog(Map item, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          title: Text(
            isApprove ? "Approve Request?" : "Reject Request?",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to ${isApprove ? 'approve' : 'reject'} the reprint for:",
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 12),
              // SCROLLABLE DOCUMENT NAME
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    item['document_name'] ?? "Untitled Document",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleAction(
                  item['id'], 
                  isApprove ? 'approved' : 'rejected', 
                  isApprove ? "Request Approved" : "Request Rejected"
                );
              },
              child: Text(
                isApprove ? "Approve" : "Reject",
                style: TextStyle(
                  color: isApprove ? const Color(0xFF78CF4E) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsPopup(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: const BoxConstraints(maxHeight: 550),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "REQUEST DETAILS",
                          style: TextStyle(
                            color: Color(0xFF78CF4E),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        _detailRow("Document Name", item['document_name']),
                        _detailRow("Requested By", item['requested_by_office']),
                        _detailRow("Request ID", item['request_id']),
                        
                        const SizedBox(height: 5),
                        _detailBox("Other Details", item['other_details']),
                      ],
                    ),
                  ),
                ),

                // OUTSIDE BORDER CLOSE BUTTON
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78CF4E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = searchCtrl.text.toLowerCase();
    final filteredList = allRequests.where((e) {
      final docName = (e['document_name'] ?? "").toString().toLowerCase();
      final reqId = (e['request_id'] ?? "").toString().toLowerCase();
      return docName.contains(query) || reqId.contains(query);
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                    : _buildList(filteredList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER WITH BADGE SUPPORT
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 20, 10),
      child: Row(
        children: [
          _backButtonWithBadge(),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "QR Reprint Requests",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Noto Sans Hebrew',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButtonWithBadge() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        adminPasswordRequestNotifier,
        adminDeletionRequestNotifier,
        adminFacultyRequestNotifier,
      ]),
      builder: (context, _) {
        final bool hasNotif = adminPasswordRequestNotifier.value > 0 ||
            adminDeletionRequestNotifier.value > 0 ||
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

  // SEARCH BAR
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: "Search Document Name or Request ID...",
                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: Icon(Symbols.search, color: Color(0xFF78CF4E), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 15, bottom: 15, right: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // REQUEST LIST
  Widget _buildList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF78CF4E),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 15),
        itemBuilder: (context, index) => _requestCard(list[index]),
      ),
    );
  }

  // INDIVIDUAL CARD
  Widget _requestCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'pending';
    final isPending = status == 'pending';
    final isUnread = item['is_read_admin'] == false;
    final color = status == 'approved'
        ? const Color(0xFF78CF4E)
        : (status == 'rejected' ? Colors.redAccent : Colors.orangeAccent);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: isPending
                    ? Colors.orangeAccent.withOpacity(0.08)
                    : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isPending
                      ? Colors.orangeAccent.withOpacity(0.3)
                      : color.withOpacity(0.3),
                  width: isUnread ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () => _showDetailsPopup(item),
                    contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    title: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              item['document_name'] ?? "Untitled",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _statusChip(status, color),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconLabel(Symbols.corporate_fare, "${item['requested_by_office'] ?? "N/A"}"),
                          const SizedBox(height: 5),
                          _iconLabel(Symbols.label_rounded, "${item['request_id'] ?? "N/A"}"),
                          const SizedBox(height: 5),
                          _iconLabel(Symbols.calendar_today, _formatDateTime(item['requested_at'])),
                        ],
                      ),
                    ),
                  ),
                  if (isPending)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(child: _actionBtn("Reject", Colors.redAccent, () => _showActionDialog(item, false))),
                          const SizedBox(width: 12),
                          Expanded(child: _actionBtn("Approve", const Color(0xFF78CF4E), () => _showActionDialog(item, true))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        if (isUnread)
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // UI COMPONENTS
  Widget _iconLabel(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.white38),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 12), overflow: TextOverflow.ellipsis)),
    ],
  );

  Widget _statusChip(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => InkWell(
    onTap: isProcessing ? null : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Symbols.print_disabled, size: 60, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 15),
        const Text("No reprint requests found", style: TextStyle(color: Colors.white24, fontSize: 14)),
      ],
    ),
  );

  

  Widget _detailRow(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), 
          style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Text(
            value ?? "N/A", 
            style: const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: 1,
          ),
        ),
      ],
    ),
  );

Widget _detailBox(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), 
          style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                value ?? "No additional details provided.", 
                style: TextStyle(
                  color: (value == null || value.isEmpty) ? Colors.white24 : Colors.white70, 
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: (value == null || value.isEmpty) ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}