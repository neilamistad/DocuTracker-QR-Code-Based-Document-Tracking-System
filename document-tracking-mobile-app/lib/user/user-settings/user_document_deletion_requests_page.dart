import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/background_wrapper.dart';

import '../../utils/user_notifications.dart';

class UserDocumentDeletionRequestsPage extends StatefulWidget {
  final String userId;
  final String userType;

  const UserDocumentDeletionRequestsPage({
    super.key,
    required this.userId,
    required this.userType,
  });

  @override
  State<UserDocumentDeletionRequestsPage> createState() => _UserDocumentDeletionRequestsPageState();
}

class _UserDocumentDeletionRequestsPageState extends State<UserDocumentDeletionRequestsPage> {
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
    if (_documentDeletionSubscription != null) {
      supabase.removeChannel(_documentDeletionSubscription!);
    }
    super.dispose();
  }

  void _initializeDocumentDeletionRealtimeListener() {
    _documentDeletionSubscription = supabase
        .channel('public:document_deletion_requests_refresher')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'document_deletion_requests',
          callback: (payload) {
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

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              SizedBox(height: 20),
              _buildSearchAndFilter(),
              Expanded(
                child: isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                  : filteredRequests.isEmpty
                    ? const Center(child: Text("No matching requests.", style: TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        itemCount: filteredRequests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 15),
                        itemBuilder: (context, index) => _buildRequestCard(filteredRequests[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 20, 10),
      child: Row(
        children: [
          _buildNotificationBackButton(context),
          
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Document Deletion Requests",
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBackButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        trackingBadgeNotifier,
        passwordRequestStatusNotifier
      ]),
      builder: (context, child) {
        final bool hasTracking = trackingBadgeNotifier.value > 0;
        final passwordData = passwordRequestStatusNotifier.value;
        final bool hasUnreadPassword = passwordData != null &&
            passwordData['is_read_user'] == false &&
            passwordData['status'] != 'pending';

        final bool showRedDot = hasTracking || hasUnreadPassword;

        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
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
              if (showRedDot)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 5, 25, 15),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              searchQuery = val;
              _applyFilters();
            },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search Document Name or ID...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Symbols.search, color: Colors.white70, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15), 
                borderSide: BorderSide.none
              ),
              contentPadding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
            ),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: _buildFilterDropdown()),
              const SizedBox(width: 12),
              _markAllButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    final filters = ["all", "pending", "approved", "rejected"];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Symbols.filter_list, color: Colors.white70, size: 18),
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedFilter = newValue;
                _applyFilters();
              });
            }
          },
          items: filters.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value.toUpperCase()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _markAllButton() {
    return TextButton(
      onPressed: _markAllAsRead,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF78CF4E).withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF78CF4E).withOpacity(0.3)),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.done_all, size: 16, color: Color(0xFF78CF4E)),
          SizedBox(width: 4),
          Text(
            "Mark all as read", 
            style: TextStyle(color: Color(0xFF78CF4E), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final String status = item['status'].toString().toLowerCase();
    final bool isUnread = item['is_read_user'] == false;

    Color statusColor;
    IconData statusIcon;
    if (status == 'approved') {
      statusColor = const Color(0xFF78CF4E);
      statusIcon = Symbols.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusIcon = Symbols.cancel;
    } else {
      statusColor = Colors.orangeAccent;
      statusIcon = Symbols.pending;
    }

    final DateTime? dt = DateTime.tryParse(item['requested_at'] ?? "");
    String formattedTimestamp = "Requested at: -- --, ---- | --:--:-- --";

    if (dt != null) {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      String month = months[dt.month - 1];
      String day = dt.day.toString().padLeft(2, '0');
      String year = dt.year.toString();
      
      int hour = dt.hour;
      String period = hour >= 12 ? "PM" : "AM";
      int hour12 = hour % 12 == 0 ? 12 : hour % 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      String second = dt.second.toString().padLeft(2, '0');

      formattedTimestamp = "Requested at: $month $day, $year | ${hour12.toString().padLeft(2, '0')}:$minute:$second $period";
    }

    return GestureDetector(
      onTap: () => isUnread ? _markAsRead(item['id'].toString()) : null,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnread ? statusColor.withOpacity(0.6) : Colors.white.withOpacity(0.1),
                    width: isUnread ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              item['document_name'] ?? "Unknown",
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isUnread) const SizedBox(width: 15),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      "ID: ${item['document_id']}", 
                      style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5, fontWeight: FontWeight.w500)
                    ),
                    
                    const Divider(height: 24, color: Colors.white10),
                    
                    Row(
                      children: [
                        const Icon(Symbols.calendar_today, size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formattedTimestamp,
                            style: const TextStyle(
                              color: Colors.white38, 
                              fontSize: 11, 
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUnread)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}