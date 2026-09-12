import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../widgets/app_background.dart';

import '../../utils/notification_utils.dart';

class DocumentDeletionRequestsPage extends StatefulWidget {
  final String userId;
  final String userType;

  const DocumentDeletionRequestsPage({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<DocumentDeletionRequestsPage> createState() => _DocumentDeletionRequestsPageState();
}

class _DocumentDeletionRequestsPageState extends State<DocumentDeletionRequestsPage> {
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> filteredRequests = [];
  
  String searchQuery = "";
  String selectedFilter = "all";
  bool isLoading = true;

  RealtimeChannel? _documentDeletionSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeDocumentDeletionRealtimeListener();
  }

  @override
  void dispose() {
    super.dispose();
    if (_documentDeletionSubscription != null) {
      supabase.removeChannel(_documentDeletionSubscription!);
    }
  }

  Future<List<Map<String, dynamic>>> fetchDeletionRequests() async {
    final res = await supabase
        .from('document_deletion_requests')
        .select('id, document_id, document_name, status, requested_at, is_read_user') 
        .eq('requested_by', widget.userId)
        .inFilter('status', ['pending', 'rejected'])
        .order('requested_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  void _initializeDocumentDeletionRealtimeListener() {
    _documentDeletionSubscription = supabase
        .channel('public:document_deletion_requests_refresher')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_deletion_requests',
          callback: (payload) {
            debugPrint("Realtime Update Detected: ${payload.eventType}");
            
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            final String? recordUserId = (newRecord['requested_by'] ?? oldRecord['requested_by'])?.toString();

            if (recordUserId == widget.userId) {
              _loadData();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    try {

      final res = await supabase
          .from('document_deletion_requests')
          .select('id, document_id, document_name, status, requested_at, is_read_user')
          .eq('requested_by', widget.userId)
          .inFilter('status', ['pending', 'rejected', 'approved'])
          .order('requested_at', ascending: false);

      if (!mounted) return;

      setState(() {
        allRequests = List<Map<String, dynamic>>.from(res);
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading requests: $e");
    }
  }

  Future<void> _markAsRead(String requestId) async {
    try {
      await supabase
          .from('document_deletion_requests')
          .update({'is_read_user': true})
          .eq('id', requestId);

      setState(() {
        for (var req in allRequests) {
          if (req['id'] == requestId) req['is_read_user'] = true;
        }
        _applyFilters();
      });
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await supabase
          .from('document_deletion_requests')
          .update({'is_read_user': true})
          .eq('requested_by', widget.userId)
          .eq('is_read_user', false);

      setState(() {
        for (var req in allRequests) {
          req['is_read_user'] = true;
        }
        _applyFilters();
      });
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  void _applyFilters() {
    setState(() {
      filteredRequests = allRequests.where((item) {
        final name = (item['document_name'] ?? "").toString().toLowerCase();
        final id = (item['document_id'] ?? "").toString().toLowerCase();
        final status = item['status'].toString().toLowerCase();
        
        final matchesSearch = name.contains(searchQuery.toLowerCase()) || id.contains(searchQuery.toLowerCase());
        final matchesFilter = selectedFilter == "all" || status == selectedFilter;
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  DropdownMenuItem<String> _dropdownItem(String label, String value) {
    return DropdownMenuItem(
      value: value,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;

              return Column(
                children: [
                  _buildHeader(), 

                  _buildSearchAndFilter(isMobile), 
                  
                  Expanded(
                    child: isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                      : filteredRequests.isEmpty
                          ? const Center(child: Text("No matching requests.", style: TextStyle(color: Colors.white54)))
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 15 : 20,
                                vertical: 10
                              ),
                              itemCount: filteredRequests.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 15),
                              itemBuilder: (context, index) => _buildRequestCard(
                                filteredRequests[index],
                              ),
                            ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEARCH BAR
          TextField(
            onChanged: (val) {
              searchQuery = val;
              _applyFilters();
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: isMobile ? "Search documents..." : "Search Document Name or ID (or Scan QR Code)",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Symbols.search, color: Color(0xFF78CF4E)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.only(top: 10, bottom: 10, right: 15),
            ),
          ),
          
          const SizedBox(height: 12),

          // FILTER CHIPS & MARK ALL ACTION
          Row(
            children: [
              isMobile 
                ? _buildFilterDropdown()
                : Row(
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
              
              const Spacer(),

              _markAllButton(isMobile),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _markAllButton(bool isMobile) {
    return TextButton.icon(
      onPressed: _markAllAsRead,
      icon: const Icon(Symbols.done_all, size: 18, color: Color(0xFF78CF4E)),
      label: const Text(
        "Mark all", 
        style: TextStyle(color: Color(0xFF78CF4E), fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.filter_list, color: Colors.white70, size: 18),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedFilter = newValue;
                _applyFilters();
              });
            }
          },
          items: [
            _dropdownItem("All", "all"),
            _dropdownItem("Pending", "pending"),
            _dropdownItem("Rejected", "rejected"),
            _dropdownItem("Approved", "approved"),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF78CF4E) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.black87 : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // UPDATED BACK BUTTON WITH NOTIFICATION BADGE
          AnimatedBuilder(
            // Nakikinig sa dalawang notifier nang sabay
            animation: Listenable.merge([trackingBadgeNotifier, passwordRequestStatusNotifier]),
            builder: (context, child) {
              final int trackingCount = trackingBadgeNotifier.value;
              final Map<String, dynamic>? passwordData = passwordRequestStatusNotifier.value;

              final bool hasUnreadPassword = passwordData != null && 
                                            passwordData['is_read_user'] == false && 
                                            passwordData['status'] != 'pending';

              final bool showRedDot = (trackingCount > 0) || hasUnreadPassword;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),

                  if (showRedDot)
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
          const Text(
            "Deletion Requests",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    String status = item['status'].toString().toLowerCase();
    bool isUnread = item['is_read_user'] == false; 

    Color statusColor;
    IconData statusIcon;
    Color cardBgColor;

    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusIcon = Symbols.check_circle;
      cardBgColor = Colors.greenAccent.withOpacity(0.1);
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusIcon = Symbols.cancel;
      cardBgColor = Colors.redAccent.withOpacity(0.15);
    } else {
      statusColor = Colors.orangeAccent;
      statusIcon = Symbols.pending;
      cardBgColor = Colors.orangeAccent.withOpacity(0.05);
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

    return GestureDetector(
      onTap: () {
        if (isUnread) _markAsRead(item['id'].toString());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                    width: isUnread ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['document_name'] ?? "Unnamed Document",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "ID: ${item['document_id']}",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Requested on: $displayDate • $displayTime",
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),

              if (isUnread)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

