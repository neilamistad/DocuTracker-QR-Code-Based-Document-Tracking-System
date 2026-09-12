import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/background_wrapper.dart';
import '../../utils/admin_notifications.dart';

class AdminDocumentDeleteRequestsPage extends StatefulWidget {
  const AdminDocumentDeleteRequestsPage({super.key});

  @override
  State<AdminDocumentDeleteRequestsPage> createState() =>
      _AdminDocumentDeleteRequestsPageState();
}

class _AdminDocumentDeleteRequestsPageState extends State<AdminDocumentDeleteRequestsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchCtrl = TextEditingController();

  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> filteredRequests = [];

  String selectedFilter = "all";
  bool isLoading = true;
  bool isProcessing = false;
  RealtimeChannel? _deleteChannel;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_deleteChannel != null) supabase.removeChannel(_deleteChannel!);
    searchCtrl.dispose();
    super.dispose();
  }

  // LOGIC
  void _setupRealtime() {
    _deleteChannel = supabase
        .channel('public:document_deletion_requests_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_deletion_requests',
          callback: (payload) => _refreshData(),
        )
        .subscribe();
  }

  Future<void> _refreshData() async {
    try {
      final res = await supabase
          .from('document_deletion_requests')
          .select()
          .order('requested_at', ascending: false);

      if (mounted) {
        setState(() {
          allRequests = List<Map<String, dynamic>>.from(res);
          _applyFilters();
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

      await supabase.from('document_deletion_requests').update({
        'status': status,
        'is_read_admin': true,
        'is_read_user': false,
      }).eq('id', requestId);

      if (mounted) {
        await AdminNotificationUtils.syncAdminBadgeCounts();
        _showTopNotification(message, status == 'approved' ? const Color(0xFF78CF4E) : Colors.redAccent);
        _refreshData();
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _showConfirmDialog(Map item, bool isApprove) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isApprove ? Colors.redAccent.withOpacity(0.2) : Colors.white10)),
          title: Text(isApprove ? "Permanently Delete?" : "Reject Request?", style: const TextStyle(color: Colors.white)),
          content: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              children: [
                TextSpan(
                  text: "Action for Document ID: ",
                ),
                TextSpan(
                  text: "${item['document_id']}?",
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleAction(item['id'].toString(), isApprove ? 'approved' : 'rejected', isApprove ? "Document Deleted" : "Request Rejected");
              },
              child: Text(isApprove ? "Proceed Delete" : "Reject", style: TextStyle(color: isApprove ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
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

  void _applyFilters() {
    final query = searchCtrl.text.toLowerCase();
    setState(() {
      filteredRequests = allRequests.where((e) {
        final docName = (e['document_name'] ?? "").toString().toLowerCase();
        final docId = (e['document_id'] ?? "").toString().toLowerCase();
        final status = e['status'].toString().toLowerCase();
        return (docName.contains(query) || docId.contains(query)) &&
               (selectedFilter == "all" || status == selectedFilter);
      }).toList();
    });
  }

  // UI COMPONENTS

  @override
  Widget build(BuildContext context) {
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
                    : _buildRequestList(),
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
          _backButtonWithBadge(),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Deletion Requests",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: searchCtrl,
                onChanged: (_) => _applyFilters(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  hintText: "Search Document Name or ID...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Symbols.search, color: Color(0xFF78CF4E), size: 20,),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15), 
                    borderSide: BorderSide.none
                  ),
                  contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // SCROLLABLE FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip("All Requests", "all", Symbols.list),
                _buildFilterChip("Pending", "pending", Symbols.pending),
                _buildFilterChip("Approved", "approved", Symbols.check_circle),
                _buildFilterChip("Rejected", "rejected", Symbols.cancel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    bool isSelected = selectedFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = value;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF78CF4E) 
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF78CF4E).withOpacity(0.5) 
                  : Colors.white10,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: const Color(0xFF78CF4E).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                size: 16, 
                color: isSelected ? Colors.black : Colors.white38
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.delete_sweep, size: 80, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 10),
            Text("No requests found", style: TextStyle(color: Colors.white.withOpacity(0.3))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF78CF4E),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
        itemCount: filteredRequests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 15),
        itemBuilder: (context, index) => _requestCard(filteredRequests[index]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'pending';
    final isUnread = item['is_read_admin'] == false;
    final isPending = status == 'pending';
    Color color = status == 'approved' ? const Color(0xFF78CF4E) : (status == 'rejected' ? Colors.redAccent : Colors.orangeAccent);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: isUnread ? Colors.orangeAccent.withOpacity(0.08) : color.withOpacity(0.04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isUnread ? Colors.orangeAccent.withOpacity(0.3) : color.withOpacity(0.1),
                  width: isUnread ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                item['document_name'] ?? "Untitled",
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16
                                ),
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "ID: ${item['document_id']}",
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      _statusChip(status, color),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  _infoRow(Symbols.person, "Requested by: ${item['requested_by']}"),
                  _infoRow(Symbols.schedule, "Date: ${item['requested_at'] != null ? _formatDateTime(item['requested_at']) : 'N/A'}"),
                  
                  if (isPending) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _actionBtn("Reject", Colors.redAccent.withOpacity(0.15), Colors.redAccent, () => _showConfirmDialog(item, false))),
                        const SizedBox(width: 12),
                        Expanded(child: _actionBtn("Approve", Color(0xFF78CF4E).withOpacity(0.15), const Color(0xFF78CF4E), () => _showConfirmDialog(item, true))),
                      ],
                    ),
                  ],
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
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Widget _backButtonWithBadge() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        adminPasswordRequestNotifier,
        adminQRReprintNotifier,
        adminFacultyRequestNotifier,
      ]),
      builder: (context, _) {
        final bool hasNotif = adminPasswordRequestNotifier.value > 0 ||
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

  // REUSABLE WIDGETS

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white24, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _actionBtn(String label, Color bg, Color txt, VoidCallback onTap) => InkWell(
    onTap: isProcessing ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: txt.withOpacity(0.2))),
      child: Text(label, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );

}