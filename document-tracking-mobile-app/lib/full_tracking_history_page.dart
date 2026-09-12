import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/background_wrapper.dart';

import '../utils/user_notifications.dart'; 
import '../utils/admin_notifications.dart';

class FullTrackingHistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? document;

  const FullTrackingHistoryPage({
    super.key,
    required this.history,
    this.document,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    
    return Scaffold(
      body: BackgroundWrapper(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('tracking_history')
              .stream(primaryKey: ['id'])
              .eq('document_id', document?['document_id'] ?? '')
              .order('updated_at', ascending: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF8BB839)));
            }

            final List<Map<String, dynamic>> liveHistory = snapshot.data ?? history;

            final displayHistory = liveHistory.reversed.toList();

            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  _buildHeader(28, 14),
                  const SizedBox(height: 25),
                  
                  Container(
                    height: 500,
                    constraints: const BoxConstraints(maxHeight: 500),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(20)),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        _buildSimpleHeader(context),
                        
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                            itemCount: displayHistory.length,
                            itemBuilder: (context, index) {
                              return _buildVerticalNode(
                                displayHistory[index], 
                                index == 0,
                                index == displayHistory.length - 1
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSimpleHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DOCUMENT ID", 
                style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
              Text(
                document?['document_id']?.toUpperCase() ?? "N/A",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          _buildStyledBackButton(context),
        ],
      ),
    );
  }

  Widget _buildStyledBackButton(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([

        // USER SIDE NOTIFIERS
        trackingBadgeNotifier,
        deletionBadgeNotifier,
        passwordRequestStatusNotifier,
        
        // ADMIN SIDE NOTIFIERS
        adminPasswordRequestNotifier,
        adminDeletionRequestNotifier,
        adminQRReprintNotifier,
        adminFacultyRequestNotifier,
      ]),
      builder: (context, child) {

        // USER SIDE LOGIC
        final bool hasUserCounts = trackingBadgeNotifier.value > 0 || deletionBadgeNotifier.value > 0;
        final passwordData = passwordRequestStatusNotifier.value;
        final bool hasUnreadPasswordUser = passwordData != null &&
            passwordData['is_read_user'] == false &&
            passwordData['status'] != 'pending';

        // ADMIN SIDE LOGIC
        final bool hasAdminCounts = adminPasswordRequestNotifier.value > 0 || 
                                    adminDeletionRequestNotifier.value > 0 || 
                                    adminQRReprintNotifier.value > 0 || 
                                    adminFacultyRequestNotifier.value > 0;

        // ALL IN ONE
        final bool showRedDot = hasUserCounts || hasUnreadPasswordUser || hasAdminCounts;

        return IconButton(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(10),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              if (showRedDot)
                Positioned(
                  right: -12,
                  top: -12,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalNode(Map<String, dynamic> item, bool isLatest, bool isLast) {
    final dt = DateTime.tryParse(item['updated_at'] ?? "");
    final day = dt != null ? "${dt.day} ${_getMonthName(dt.month)}" : "--";
    final time = dt != null ? _getFormattedTime(dt) : "--:--";

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(day, style: TextStyle(color: isLatest ? const Color(0xFF8BB839) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(time, style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLatest ? const Color(0xFF8BB839) : Colors.white10,
                    boxShadow: isLatest ? [
                      BoxShadow(color: const Color(0xFF8BB839).withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                    ] : [],
                    border: Border.all(color: isLatest ? Colors.white : Colors.transparent, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            isLatest ? const Color(0xFF8BB839).withOpacity(0.5) : Colors.white10,
                            Colors.white.withOpacity(0.01),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLatest ? const Color(0xFF8BB839).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isLatest ? const Color(0xFF8BB839).withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                  ),
                  child: Text(
                    item['status'] ?? "Status",
                    style: TextStyle(color: isLatest ? const Color(0xFF8BB839) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_pin, size: 14, color: Colors.white24),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item['office'] ?? "Office",
                        style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double titleSize, double subSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Text('Full Tracking History', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: titleSize, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Monitor the real-time location of your documents.', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: subSize)),
        ],
      ),
    );
  }

  String _getMonthName(int m) => ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m - 1];
  String _getFormattedTime(DateTime dt) => "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}";
}