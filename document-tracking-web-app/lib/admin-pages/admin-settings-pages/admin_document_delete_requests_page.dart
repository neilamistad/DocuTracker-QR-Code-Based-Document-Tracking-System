import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../../widgets/app_background.dart';

import '../../utils/admin_notification_utils.dart';

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

  // LOGIC: REALTIME SYNC
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

  // LOGIC: FETCH & NOTIFICATION MARKER
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
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // LOGIC: DECISION ACTION
  Future<void> _handleAction(String requestId, String status, String message) async {
    setState(() => isProcessing = true);
    try {
      await supabase
          .from('document_deletion_requests')
          .update({
            'status': status,
            'is_read_admin': true,
            'is_read_user' : false,
          })
          .eq('id', requestId);
      
      if (mounted) {
        await AdminNotificationUtils.syncAdminBadgeCounts();

        _showTopNotification(message, status == 'approved' ? Colors.green : Colors.red);

        _refreshData();
      }
    } catch (e) {
      if (mounted) _showTopNotification("Error: $e", Colors.red);

    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await supabase
          .from('document_deletion_requests')
          .update({'is_read_admin': true})
          .eq('is_read_admin', false);

      setState(() {
        for (var req in allRequests) {
          req['is_read_admin'] = true;
        }
        _applyFilters();
      });
      
      await AdminNotificationUtils.syncAdminBadgeCounts();
    } catch (e) {
      debugPrint("Mark all error: $e");
    }
  }

  void _showActionDialog(Map item, bool isApproving) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
        title: Text(isApproving ? "Confirm Deletion" : "Reject Request", style: const TextStyle(color: Colors.white)),
        content: Text(
          isApproving 
            ? "Are you sure you want to PERMANENTLY delete '${item['document_name']}'? This cannot be undone."
            : "Reject the deletion request for '${item['document_name']}'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isApproving ? Colors.redAccent : Colors.orangeAccent),
            onPressed: () {
              Navigator.pop(context);
              _handleAction(item['id'].toString(), isApproving ? 'approved' : 'rejected', isApproving ? "Document Purged Successfully" : "Request Rejected");
            },
            child: Text(isApproving ? "Confirm Delete" : "Reject Request", style: const TextStyle(color: Colors.white)),
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

  void _applyFilters() {
    final query = searchCtrl.text.toLowerCase();
    setState(() {
      filteredRequests = allRequests.where((e) {
        final docName = (e['document_name'] ?? "").toString().toLowerCase();
        final docId = (e['document_id'] ?? "").toString().toLowerCase();
        final status = e['status'].toString().toLowerCase();

        final matchesSearch = docName.contains(query) || docId.contains(query);
        final matchesFilter = selectedFilter == "all" || status == selectedFilter;

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchAndFilter(),
              Expanded(
                child: isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                  : _buildList(filteredRequests),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> filteredList) {
    if (filteredList.isEmpty) {
      return _buildEmptyState(isSearching: searchCtrl.text.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF78CF4E),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filteredList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 15),
        itemBuilder: (context, index) => _buildRequestCard(filteredList[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final status = item['status'].toString().toLowerCase();
    bool isPending = status == 'pending';
    bool isUnread = item['is_read_admin'] == false;
    
    Color statusColor;
    IconData statusIcon;
    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusIcon = Symbols.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusIcon = Symbols.cancel;
    } else {
      statusColor = Colors.orangeAccent;
      statusIcon = Symbols.pending;
    }

    final DateTime? dt = DateTime.tryParse(item['requested_at'] ?? "");

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
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.5),
                  width: isUnread ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              item['document_name'] ?? "No Name",
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 18, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _statusBadge(status, statusColor, statusIcon),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Symbols.id_card, "Doc ID: ${item['document_id']}"),
                    _infoRow(Symbols.person, "Requested by: ${item['requested_by']}"),
                    _infoRow(Symbols.calendar_today, "Requested: $displayDate • $displayTime"),
                    
                    if (isPending) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _actionButton("Reject", Colors.redAccent.withOpacity(0.1), Colors.redAccent, () => _showActionDialog(item, false))),
                          const SizedBox(width: 15),
                          Expanded(child: _actionButton("Approve Delete", const Color(0xFF78CF4E).withOpacity(0.1), const Color(0xFF78CF4E), () => _showActionDialog(item, true))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUnread)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // UI HELPERS
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
              adminQRReprintNotifier,
              adminFacultyRequestNotifier,
            ]),
            builder: (context, child) {

              final bool hasNotification = (adminPasswordRequestNotifier.value > 0) ||  
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
          Text("Deletion Management", style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [

          // SEARCH BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: TextField(
                controller: searchCtrl,
                onChanged: (_) => _applyFilters(),
                style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 15),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  hintText: "Search Document Name or ID...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF78CF4E)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // FILTER CHIPS & MARK ALL
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip("All", "all"),
                      const SizedBox(width: 8),
                      _filterChip("Pending", "pending"),
                      const SizedBox(width: 8),
                      _filterChip("Rejected", "rejected"),
                      const SizedBox(width: 8),
                      _filterChip("Approved", "approved"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(Symbols.done_all, size: 18, color: Color(0xFF78CF4E)),
                label: const Text("Mark all", style: TextStyle(color: Color(0xFF78CF4E), fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    bool isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF78CF4E) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.black87 : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );

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
      child: Text(label, style: TextStyle(color: border, fontWeight: FontWeight.bold, fontSize: 14)),
    ),
  );

  Widget _buildEmptyState({required bool isSearching}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSearching ? Symbols.search_off : Symbols.inventory_2, size: 60, color: Colors.white24),
          const SizedBox(height: 15),
          Text(isSearching ? "No matching requests" : "No deletion requests yet", style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}