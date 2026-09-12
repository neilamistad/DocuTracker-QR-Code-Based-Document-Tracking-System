import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../widgets/app_background.dart';
import '../../utils/admin_notification_utils.dart';

class AdminQRReprintRequestsPage extends StatefulWidget {
  const AdminQRReprintRequestsPage({super.key});

  @override
  State<AdminQRReprintRequestsPage> createState() => _AdminQRReprintRequestsPageState();
}

class _AdminQRReprintRequestsPageState extends State<AdminQRReprintRequestsPage> {
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
      callback: (payload) {
        _refreshData();
      },
    ).subscribe();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    final data = await fetchReprintRequests();
    if (mounted) {
      setState(() {
        allRequests = data;
        isLoading = false;
      });
    }
  }

  // LOGIC: FETCH DATA (Ordered by Latest)
  Future<List<Map<String, dynamic>>> fetchReprintRequests() async {
    try {
      final res = await supabase
          .from('qr_reprint_requests')
          .select()
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Fetch Error: $e");
      return [];
    }
  }

  // LOGIC: UPDATE STATUS
  Future<void> _handleAction(String requestId, String status, String message) async {
    setState(() => isProcessing = true);
    try {

      await supabase
          .from('qr_reprint_requests')
          .update({
            'status': status,
            'is_read_admin': true,
            'is_read_user' : false
          }).eq('id', requestId);
      
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

  void _showActionDialog(Map item, bool isApproving) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white24),
            ),
            title: Text(isApproving ? "Approve Reprint" : "Reject Request", style: const TextStyle(color: Colors.white)),
            content: Text(
              isApproving 
                ? "Confirming this will allow the office to generate a new QR label for '${item['document_name']}'."
                : "Are you sure you want to reject the reprint request for '${item['document_name']}'?",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isApproving ? const Color(0xFF78CF4E) : Colors.orangeAccent),
                onPressed: () {
                  Navigator.pop(context);
                  _handleAction(item['id'], isApproving ? 'approved' : 'rejected', isApproving ? "Reprint approved." : "Request rejected.");
                },
                child: Text(isApproving ? "Approve" : "Reject Request", style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    // Kunin ang actual data
    final String docName = item['document_name'] ?? "N/A";
    final String otherDetails = item['other_details'] ?? "No additional details provided.";

    showDialog(
      context: context,
      builder: (context) => Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white24),
            ),
            title: Row(
              children: [
                const Icon(Symbols.info, color: Color(0xFF78CF4E)),
                const SizedBox(width: 10),
                const Text("Request Details", style: TextStyle(color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modalDocumentName(docName),

                    const SizedBox(height: 20),
                    
                    _modalInfoLabel("Office"),
                    const SizedBox(height: 5),
                    Text(
                      item['requested_by_office'] ?? "N/A", 
                      style: const TextStyle(color: Colors.white, fontSize: 16)
                    ),

                    const SizedBox(height: 20),

                    _modalAdditionalDetails(otherDetails),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: Color(0xFF78CF4E))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatDateTime(String? rawTimestamp) {
    if (rawTimestamp == null || rawTimestamp.isEmpty) return "--:--";

    try {
      String cleanTimestamp = rawTimestamp.split('+')[0];
      if (!cleanTimestamp.endsWith('Z')) cleanTimestamp += 'Z';
      cleanTimestamp = cleanTimestamp.replaceAll(' ', 'T');

      DateTime dbTime = DateTime.parse(cleanTimestamp);

      final int hour24 = dbTime.hour; 
      final String amPm = hour24 >= 12 ? "PM" : "AM";
      final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final String minute = dbTime.minute.toString().padLeft(2, '0');
      
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final String displayDate = "${months[dbTime.month - 1]} ${dbTime.day}, ${dbTime.year}";

      return "$displayDate | $hour12:$minute $amPm";
    } catch (e) {
      return rawTimestamp.substring(0, 10); 
    }
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
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
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
              adminFacultyRequestNotifier,
            ]),
            builder: (context, child) {
              final bool hasNotification = (adminPasswordRequestNotifier.value > 0) || 
                                            (adminDeletionRequestNotifier.value > 0) || 
                                            (adminFacultyRequestNotifier.value > 0);

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
          
          // RESPONSIVE TITLE
          Flexible(
            child: Text(
              "QR Reprint Requests",
              style: TextStyle(
                fontSize: isMobile ? 18 : 24, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
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
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: "Search Request ID or Document Name...",
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

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final status = item['status'];
    bool isPending = status == 'pending';
    bool isUnread = item['is_read_admin'] == false; 
    Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    
    return Stack(
      children: [
        // MAIN CARD
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUnread ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                  width: isUnread ? 1.5 : 1
                ),
              ),
              child: InkWell(
                onTap: () => _showDetailsDialog(item),
                borderRadius: BorderRadius.circular(20),
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
                                item['document_name'] ?? "Unknown", 
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _statusBadge(status, statusColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow(Symbols.corporate_fare, "Office: ${item['requested_by_office']}"),
                      _infoRow(Symbols.label, "Request ID: ${item['request_id']}"),
                      _infoRow(Symbols.calendar_today, formatDateTime(item['requested_at'])),
                      
                      if (isPending) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _actionButton("Reject", Colors.redAccent.withOpacity(0.1), Colors.redAccent, () => _showActionDialog(item, false))),
                            const SizedBox(width: 15),
                            Expanded(child: _actionButton("Approve", const Color(0xFF78CF4E).withOpacity(0.1), const Color(0xFF78CF4E), () => _showActionDialog(item, true))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // RED DOT
        if (isUnread)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
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

  Widget _buildEmptyState({required bool isSearching}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSearching ? Symbols.search_off : Symbols.print_disabled, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          Text(isSearching ? "No matching requests" : "No reprint requests yet", style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
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
      child: Text(label, style: TextStyle(color: border, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _modalInfoLabel(String label) => Text(label.toUpperCase(), 
    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2));

  Widget _modalDocumentName(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modalInfoLabel("Document Name"),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modalAdditionalDetails(String details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modalInfoLabel("Additional Details"),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: Text(
              details.isEmpty ? "No additional details provided." : details,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}