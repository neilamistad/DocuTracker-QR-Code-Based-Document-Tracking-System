import 'package:flutter/material.dart';
import '../widgets/app_background.dart';

import '../utils/other_office_notification_utils.dart';

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
    const double nodeSpacing = 300.0;
    const double startX = 100.0;
    
    final List<Map<String, dynamic>> chronologicalHistory = history.reversed.toList();
    double timelineWidth = (chronologicalHistory.length <= 1) 
        ? 1464 
        : (chronologicalHistory.length * nodeSpacing) + 200;

    return Scaffold(
      body: AppBackground(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: Stack(
                children: [
                  Positioned(
                    top: 150, left: 0, right: 0,
                    child: Column(
                      children: [
                        const Text('Tracking History',
                          style: TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold)),
                        const Text('Monitor the real-time location and transfer history of your files.',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w200)),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 228, top: 450,
                    child: Container(
                      width: 1464, height: 450,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white.withValues(alpha: 1.0)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 74,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 10,
                                  top: 0,
                                  bottom: 0,
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: reprintBadgeNotifier,
                                    builder: (context, badgeCount, child) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                          
                                          if (badgeCount > 0)
                                            Positioned(
                                              right: 8,
                                              top: 12, 
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 2,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                Center(
                                  child: Text(document?['document_id'] ?? "No ID",
                                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          
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
                                          left: startX + 13, top: 148,
                                          child: Container(
                                            width: (chronologicalHistory.length - 1) * nodeSpacing,
                                            height: 3, 
                                            color: Colors.white.withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ...List.generate(chronologicalHistory.length, (index) {
                                        final item = chronologicalHistory[index];
                                        final isLatest = index == chronologicalHistory.length - 1;
                                        final double currentX = startX + (index * nodeSpacing);
                                        return _buildNode(currentX, item, isLatest);
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
        ),
      ),
    );
  }

  Widget _buildNode(double x, Map<String, dynamic> item, bool isLatest) {
    final dt = DateTime.tryParse(item['updated_at'] ?? "");

    return Stack(
      children: [
        Positioned(
          left: x,
          top: 136,
          child: Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),

        Positioned(
          left: x - 50,
          top: 70,
          child: SizedBox(
            width: 134,
            child: Text(
              dt != null ? "${dt.day} ${_getMonthName(dt.month)}" : "-",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isLatest ? const Color.fromARGB(255, 255, 196, 78) : Colors.white, 
                fontSize: 20, 
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        Positioned(
          left: x - 50,
          top: 95,
          child: SizedBox(
            width: 134,
            child: Text(
              dt != null ? _getFormattedTime(dt) : "-",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 16),
            ),
          ),
        ),

        Positioned(
          left: x - 53,
          top: 180,
          child: Container(
            width: 134,
            height: 41,
            decoration: BoxDecoration(
              color: const Color(0x19D9D9D9),
              border: Border.all(color: isLatest ? const Color.fromARGB(255, 85, 212, 151) : Colors.white),
              borderRadius: BorderRadius.circular(2300),
            ),
            child: Center(
              child: Text(
                item['status'] ?? "Status",
                style: TextStyle(
                  color: isLatest ? const Color.fromARGB(255, 85, 212, 151) : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left: x - 85,
          top: 230,
          child: SizedBox(
            width: 200,
            child: Text(
              item['office'] ?? "Office",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFAFAFAF), fontSize: 18, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }

  // HELPERS

  String _getMonthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }

  String _getFormattedTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$h:$m $ampm";
  }
}