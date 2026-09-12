import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/notification_utils.dart';

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
      body: AppBackground(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('document_tracking')
              .stream(primaryKey: ['id'])
              .eq('document_id', document?['document_id'] ?? '')
              .order('updated_at', ascending: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final List<Map<String, dynamic>> liveHistory = snapshot.data ?? history;

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 1100;
                if (isDesktop) {
                  return _buildDesktopHorizontal(context, liveHistory);
                } else {
                  return _buildMobileVertical(context, liveHistory);
                }
              },
            );
          },
        ),
      ),
    );
  }

  // DESKTOP VIEW
  Widget _buildDesktopHorizontal(BuildContext context, List<Map<String, dynamic>> chronologicalHistory) {
    const double nodeSpacing = 300.0;
    const double startX = 100.0;
    double timelineWidth = (chronologicalHistory.length <= 1) 
        ? 1464 
        : (chronologicalHistory.length * nodeSpacing) + 200;

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Stack(
            children: [

              Positioned(
                top: 150,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildHeader(96, 20),
                ),
              ),
              Positioned(
                left: 228, top: 450,
                child: Container(
                  width: 1464, height: 450,
                  decoration: _glassDecoration(),
                  child: Column(
                    children: [
                      _buildDesktopNav(context),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 50),
                          child: Center(
                            child: SizedBox(
                              width: timelineWidth > 1364 ? timelineWidth : 1364,
                              height: 300,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (chronologicalHistory.length > 1)
                                    Positioned(
                                      left: startX + 13, top: 128,
                                      child: Container(
                                        width: (chronologicalHistory.length - 1) * nodeSpacing,
                                        height: 3, 
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ...List.generate(chronologicalHistory.length, (index) {
                                    final item = chronologicalHistory[index];
                                    final isLatest = index == chronologicalHistory.length - 1;
                                    return _buildHorizontalNode(startX + (index * nodeSpacing), item, isLatest);
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileVertical(BuildContext context, List<Map<String, dynamic>> chronologicalHistory) {
    final displayHistory = chronologicalHistory.reversed.toList();

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Center(child: _buildHeader(35, 16)), 
          const SizedBox(height: 20),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            document?['document_id']?.toUpperCase() ?? "",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        Positioned(
                          right: 0,
                          child: ListenableBuilder(
                            listenable: Listenable.merge([trackingBadgeNotifier, deletionBadgeNotifier]),
                            builder: (context, child) {
                              final bool hasNotification = trackingBadgeNotifier.value > 0 || deletionBadgeNotifier.value > 0;
                              
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  if (hasNotification)
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        width: 10,
                                        height: 10,
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
                          ),
                        )
                      ],
                    ),
                  ),
                  // TIMELINE LIST
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 30),
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
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // REUSABLE UI HELPERS

  BoxDecoration _glassDecoration() => BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    border: Border.all(color: Colors.white.withOpacity(1.00)),
    borderRadius: BorderRadius.circular(25),
  );

  Widget _buildHeader(double titleSize, double subSize) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Full Tracking History',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Monitor the real-time location and transfer history of your files.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: subSize,
          fontWeight: FontWeight.w200,
        ),
      ),
    ],
  );
}

  Widget _buildDesktopNav(BuildContext context) => Container(
    height: 74,
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
    child: Stack(
      children: [
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              trackingBadgeNotifier, 
              deletionBadgeNotifier, 
              passwordRequestStatusNotifier
            ]),
            builder: (context, child) {
              final bool hasTrackingOrDeletion = trackingBadgeNotifier.value > 0 || deletionBadgeNotifier.value > 0;
              final passwordData = passwordRequestStatusNotifier.value;
              final bool hasUnreadPassword = passwordData != null && 
                                            passwordData['is_read_user'] == false && 
                                            passwordData['status'] != 'pending';

              final bool hasNotification = hasTrackingOrDeletion || hasUnreadPassword;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (hasNotification)
                    Positioned(
                      right: 8,
                      top: 15,
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
        ),
        Center(
          child: Text(
            document?['document_id'] ?? "No ID",
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  Widget _buildVerticalNode(Map<String, dynamic> item, bool isLatest, bool isLast) {
    final dt = DateTime.tryParse(item['updated_at'] ?? "");
    final day = dt != null ? "${dt.day} ${_getMonthName(dt.month)}" : "--";
    final time = dt != null ? _getFormattedTime(dt) : "--:--";

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(day, style: TextStyle(color: isLatest ? const Color(0xFFFFC44E) : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),

          SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: isLatest ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 4,
                    ),
                  ] : [],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isLatest ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.05),
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
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLatest ? const Color(0xFF55D497) : Colors.white38,
                      width: isLatest ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    item['status'] ?? "Status",
                    style: TextStyle(
                      color: isLatest ? const Color(0xFF55D497) : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['office'] ?? "Office",
                  style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalNode(double x, Map<String, dynamic> item, bool isLatest) {
    final dt = DateTime.tryParse(item['updated_at'] ?? "");
    return Stack(
      children: [
        Positioned(
        left: x,
        top: 116,
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: isLatest ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.6),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ] : [], 
          ),
        ),
      ),
        Positioned(left: x, top: 116, child: Container(width: 27, height: 27, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
        Positioned(left: x - 50, top: 40, child: SizedBox(width: 134, child: Text(dt != null ? "${dt.day} ${_getMonthName(dt.month)}" : "-", textAlign: TextAlign.center, style: TextStyle(color: isLatest ? const Color(0xFFFFC44E) : Colors.white, fontSize: 20, fontWeight: FontWeight.w600)))),
        Positioned(left: x - 50, top: 65, child: SizedBox(width: 134, child: Text(dt != null ? _getFormattedTime(dt) : "-", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 16)))),
        Positioned(
          left: x - 53, 
          top: 160, 
          child: Container(
            width: 134, 
            height: 51, 
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0x19D9D9D9), 
              border: Border.all(
                color: isLatest ? const Color(0xFF55D497) : Colors.white,
                width: isLatest ? 2 : 1,
              ), 
              borderRadius: BorderRadius.circular(2300),
            ), 
            child: Center(
              child: Text(
                item['status'] ?? "Status", 
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLatest ? const Color(0xFF55D497) : Colors.white, 
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
        Positioned(left: x - 85, top: 230, child: SizedBox(width: 200, child: Text(item['office'] ?? "Office", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 18, fontStyle: FontStyle.italic)))),
      ],
    );
  }

  String _getMonthName(int m) => ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m - 1];
  String _getFormattedTime(DateTime dt) => "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}";
}