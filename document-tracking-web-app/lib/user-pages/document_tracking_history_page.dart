import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/notification_utils.dart';

import '../pages/full_tracking_history_page.dart';

class DocumentTrackingHistoryPage extends StatefulWidget {
  final String userType; 
  final String userId;

  const DocumentTrackingHistoryPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<DocumentTrackingHistoryPage> createState() => _DocumentTrackingHistoryPageState();
}

class _DocumentTrackingHistoryPageState extends State<DocumentTrackingHistoryPage> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _historySubscription;

  List<Map<String, dynamic>> historyList = [];
  bool isLoading = false;
  int unreadCount = 0;

  Set<dynamic> unreadEntryIds = {};

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
          debugPrint("Realtime Update: Refreshing history list...");
          fetchHistory(isSilent: true);
        }
      },
    )
    .subscribe();
  }

  // UI BADGE LOGIC
  String getBadgeText(int count) {
    if (count > 99) return "99+";
    return count.toString();
  }

  /// FETCH HISTORY
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
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  String formatTo12Hour(String rawDate) {
    try {

      DateTime dt = DateTime.parse(rawDate); 
      
      int hour = dt.hour;
      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour; 
      
      String minute = dt.minute.toString().padLeft(2, '0');
      return "$hour:$minute $period";
    } catch (e) {
      return rawDate;
    }
  }

  String formatDate(String rawDate) {
    try {
      DateTime dt = DateTime.parse(rawDate); 
      
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (e) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    Widget headerSection = Padding(
      padding: EdgeInsets.only(
        left: isDesktop ? 100 : 25, 
        right: isDesktop ? 100 : 25, 
        top: 40, 
        bottom: 20
      ),
      child: Column(
        children: [
          Text(
            'Tracking History',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 75 : 35,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Monitor real-time updates of your documents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70, 
              fontSize: isDesktop ? 16 : 14, 
              fontWeight: FontWeight.w200
            ),
          ),
        ],
      ),
    );

    Widget footerSection = (historyList.isNotEmpty && !isLoading)
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'Tip: Click Tracking History button again to mark all as read',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.2), 
                fontSize: isDesktop ? 16 : 12, 
                fontStyle: FontStyle.italic
              ),
            ),
          )
        : const SizedBox.shrink();

    return isDesktop
        ? Column(
            children: [
              headerSection,
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
                    : RefreshIndicator(
                        onRefresh: () => fetchHistory(isSilent: true),
                        color: const Color(0xFF78CF4E),
                        child: _buildResultsContainer(isDesktop, isScrollable: true),
                      ),
              ),
              footerSection,
            ],
          )
        : RefreshIndicator(
            onRefresh: () => fetchHistory(isSilent: true),
            color: const Color(0xFF78CF4E),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  headerSection,
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
                    )
                  else
                    _buildResultsContainer(isDesktop, isScrollable: false),
                  footerSection,
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, bool isDesktop) {
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
        final navigator = Navigator.of(context);
        try {
          final response = await supabase
              .from('tracking_history')
              .select()
              .eq('document_id', item['document_id'])
              .order('updated_at', ascending: true);
              
          if (!mounted) return;
          navigator.push(MaterialPageRoute(
              builder: (_) => FullTrackingHistoryPage(
                  history: List<Map<String, dynamic>>.from(response),
                  document: item)));
        } catch (e) {
          debugPrint(e.toString());
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            decoration: BoxDecoration(
              color: isUnread 
                  ? (isCorrected ? Colors.orangeAccent.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.15)) 
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: isUnread 
                  ? Border.all(color: isCorrected ? Colors.orangeAccent : Colors.greenAccent, width: 1) 
                  : Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isDesktop ? 3 : 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item['document_id'] ?? 'N/A',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: isDesktop ? 18 : 14, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          if (isUnread && isDesktop) ...[
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                          ],
                        ],
                      ),
                      if (!isDesktop) ...[
                        const SizedBox(height: 4),
                        Text(
                          item['status'].toString().toUpperCase(),
                          style: const TextStyle(color: Color(0xFF78CF4E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDesktop)
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['status'].toString().toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF78CF4E), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                Expanded(
                  flex: isDesktop ? 2 : 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatTo12Hour(item['updated_at'].toString()), 
                        style: TextStyle(color: Colors.white, fontSize: isDesktop ? 14 : 12, fontWeight: FontWeight.w500)
                      ),
                      Text(
                        formatDate(item['updated_at'].toString()), 
                        style: TextStyle(color: Colors.white38, fontSize: isDesktop ? 12 : 10)
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Colors.white12, size: 18),
              ],
            ),
          ),
          if (isUnread && !isDesktop)
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
    );
  }

  Widget _buildResultsContainer(bool isDesktop, {required bool isScrollable}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 20, vertical: 10),
          child: _buildHistoryList(isDesktop, isScrollable: isScrollable),
        ),
      ),
    );
  }

  Widget _buildHistoryList(bool isDesktop, {required bool isScrollable}) {
    if (historyList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Text("No tracking history found", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: !isScrollable,
      physics: isScrollable 
        ? const AlwaysScrollableScrollPhysics() 
        : const NeverScrollableScrollPhysics(),
      itemCount: historyList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = historyList[index];
        return _buildHistoryCard(item, isDesktop);
      },
    );
  }
}