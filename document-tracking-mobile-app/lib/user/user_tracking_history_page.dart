import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/user_notifications.dart';

import '../widgets/background_wrapper.dart';

import '../full_tracking_history_page.dart';

class UserDocumentTrackingHistoryPage extends StatefulWidget {
  final String userType;
  final String userId;

  const UserDocumentTrackingHistoryPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<UserDocumentTrackingHistoryPage> createState() => _UserDocumentTrackingHistoryPageState();
}

class _UserDocumentTrackingHistoryPageState extends State<UserDocumentTrackingHistoryPage> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _historySubscription;

  List<Map<String, dynamic>> historyList = [];
  bool isLoading = false;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    fetchHistory();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    if (_historySubscription != null) {
      supabase.removeChannel(_historySubscription!);
    }
    super.dispose();
  }

  void _setupRealtimeListener() {
    _historySubscription = supabase
      .channel('public:tracking_history_list')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tracking_history',
        callback: (payload) {
          final record = payload.newRecord.isEmpty ? payload.oldRecord : payload.newRecord;
          if (record['registered_by_id']?.toString() == widget.userId) {
            fetchHistory(isSilent: true);
          }
        },
      )
      .subscribe();
  }

  Future<void> fetchHistory({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => isLoading = true);

    try {
      final data = await supabase
          .from('tracking_history')
          .select()
          .eq('registered_by_id', widget.userId)
          .eq('registered_by_type', widget.userType.toLowerCase())
          .order('updated_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          historyList = List<Map<String, dynamic>>.from(data);
          unreadCount = historyList.where((item) => item['is_read'] == false).length;
          trackingBadgeNotifier.value = unreadCount;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String formatTo12Hour(String rawDate) {
    try {
      DateTime dt = DateTime.parse(rawDate);
      int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      String period = dt.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $period";
    } catch (e) {
      return "--:--";
    }
  }

  String formatDate(String rawDate) {
    try {
      DateTime dt = DateTime.parse(rawDate).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (e) {
      return "--- --, ----";
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () => fetchHistory(isSilent: true),
          color: const Color(0xFF78CF4E),
          backgroundColor: const Color(0xFF1A1A1A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(25, 80, 25, 25),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Tracking History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Monitor real-time updates of your documents.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ]),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    'Tip: Click the tracking history navigation button again to mark all as read',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.20),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: isLoading
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E))),
                        ),
                      )
                    : historyList.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Center(child: Text("No tracking history found", style: TextStyle(color: Colors.white38))),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHistoryCard(historyList[index]),
                                );
                              },
                              childCount: historyList.length,
                            ),
                          ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 180, 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final bool isUnread = item['is_read'] == false;
    final bool isCorrected = item['is_corrected'] ?? false;

    return InkWell(
      onTap: () async {
        if (isUnread) {
          await supabase
              .from('tracking_history')
              .update({'is_read': true})
              .eq('history_id', item['history_id']);
          
          if (mounted) {
            setState(() {
              item['is_read'] = true;
              if (unreadCount > 0) unreadCount--;
              trackingBadgeNotifier.value = unreadCount;
            });
          }
        }

        if (!mounted) return;
        
        try {
          final response = await supabase
              .from('tracking_history')
              .select()
              .eq('document_id', item['document_id'])
              .order('updated_at', ascending: true);
              
          if (!mounted) return;

          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => FullTrackingHistoryPage(
                history: List<Map<String, dynamic>>.from(response),
                document: item,
              ),
            ),
          );
        } catch (e) {
          debugPrint(e.toString());
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isUnread 
                  ? (isCorrected ? Colors.orangeAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1)) 
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnread 
                    ? (isCorrected ? Colors.orangeAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.5)) 
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: isUnread ? (isCorrected ? Colors.orangeAccent : Colors.greenAccent) : Colors.white24,
                        size: 22,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['document_id'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['status'].toString().toUpperCase(),
                        style: TextStyle(
                          color: isCorrected ? Colors.orangeAccent : const Color(0xFF78CF4E),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatTo12Hour(item['updated_at'].toString()),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatDate(item['updated_at'].toString()),
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white12, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}