import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../widgets/app_background.dart';

import '../utils/admin_notification_utils.dart';

import '../pages/full_tracking_history_page.dart';

class AdminDocumentInfoPage extends StatefulWidget {
  final Map<String, dynamic> document;

  const AdminDocumentInfoPage({super.key, required this.document});

  @override
  State<AdminDocumentInfoPage> createState() => _AdminDocumentInfoPageState();
}

class _AdminDocumentInfoPageState extends State<AdminDocumentInfoPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController nameCtrl;
  late TextEditingController detailsCtrl;
  String? selectedType;

  List<Map<String, dynamic>> trackingHistory = [];
  bool isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.document['document_name']);
    detailsCtrl = TextEditingController(text: widget.document['details'] ?? '');
    selectedType = widget.document['document_type'];
    fetchTrackingHistory();
  }

  Future<void> fetchTrackingHistory() async {
    try {
      final response = await supabase
          .from('tracking_history')
          .select()
          .eq('document_id', widget.document['document_id'])
          .order('updated_at', ascending: true);
      setState(() {
        trackingHistory = List<Map<String, dynamic>>.from(response);
        isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = trackingHistory.isNotEmpty ? trackingHistory.last : null;
    DateTime? regDate;
    if (trackingHistory.isNotEmpty) {
      final reg = trackingHistory.firstWhere((item) => item['status'] == 'Registered', orElse: () => trackingHistory.first);
      regDate = DateTime.tryParse(reg['updated_at'] ?? "");
    }


    String currentTime = "--:--";
    String currentDate = "----/--/--";

    if (latest != null) {
      final dt = DateTime.tryParse(latest['updated_at'] ?? "");
      if (dt != null) {
        currentTime = "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}";
        
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        currentDate = "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
      }
    }

      return Scaffold(
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 1100;
            
            if (isDesktop) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 1920,
                    height: 1080,
                    child: _buildDesktopLayout(latest, currentTime, currentDate, regDate),
                  ),
                ),
              );
            } else {
              return SafeArea(
                child: _buildMobileLayout(latest, currentTime, currentDate, regDate),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Map? latest, String time, String date, DateTime? regDate) {
    return Stack(
      children: [
        Positioned(left: 60, top: 60, child: _backBtn(false)),
        _pos(100, 300, 650, null, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document \nInfo', style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white)),
            const SizedBox(height: 30),
            const Text('Detailed administrative view of document\nclassification and full audit trail.', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w200)),
          ],
        )),
        _pos(850, 150, 950, 850, _buildGlassyCard(latest, time, date, regDate, false)),
      ],
    );
  }

  Widget _buildMobileLayout(Map? latest, String time, String date, DateTime? regDate) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 5),
          child: Row(
            children: [
              _backBtn(true), 
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Document Info',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
              ),
            ],
          ),
        ),

        // SCROLLABLE CONTENT
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Detailed administrative view of document classification and full audit trail.',
                  style: TextStyle(
                    color: Colors.white70, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w200
                  )
                ),
                
                const SizedBox(height: 30),
                
                _buildGlassyCard(latest, time, date, regDate, true),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassyCard(Map? latest, String time, String date, DateTime? regDate, bool isMobile) {
    double padding = isMobile ? 20 : 60;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobile 
                ? Column(
                    children: [
                      _fieldLabel("DOCUMENT ID", _inputBox(widget.document['document_id'], isReadOnly: true, isMobile: isMobile)),
                      const SizedBox(height: 25),
                      _fieldLabel("DOCUMENT NAME", _inputBox("", controller: nameCtrl, isReadOnly: true, isMobile: isMobile)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _fieldLabel("DOCUMENT ID", _inputBox(widget.document['document_id'], isReadOnly: true, isMobile: isMobile))),
                      const SizedBox(width: 40),
                      Expanded(child: _fieldLabel("DOCUMENT NAME", _inputBox("", controller: nameCtrl, isReadOnly: true, isMobile: isMobile))),
                    ],
                  ),
              
              const SizedBox(height: 30),

              isMobile 
                ? Column(
                    children: [
                      _fieldLabel("REGISTERED AT", _dateDisplay(regDate, isMobile)),
                      const SizedBox(height: 25),
                      _fieldLabel("TYPE OF DOCUMENT", _inputBox(selectedType ?? "N/A", isReadOnly: true, isMobile: isMobile)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _fieldLabel("REGISTERED AT", _dateDisplay(regDate, isMobile))),
                      const SizedBox(width: 40),
                      Expanded(child: _fieldLabel("TYPE OF DOCUMENT", _inputBox(selectedType ?? "N/A", isReadOnly: true, isMobile: isMobile))),
                    ],
                  ),

              const SizedBox(height: 30),
              
              _fieldLabel("ADDITIONAL DETAILS", _largeBox(detailsCtrl, isMobile)),
              
              const SizedBox(height: 30),
              
              _fieldLabel(
                "REGISTERED BY (USER ID)", 
                _inputBox(
                  widget.document['registered_by_id']?.toString() ?? "N/A", 
                  isReadOnly: true, 
                  isMobile: isMobile
                )
              ),

              const SizedBox(height: 30),
              
              _fieldLabel("LATEST TRACKING STATUS", _statusCard(latest, time, date, isMobile: isMobile)),
            ],
          ),
        ),
      ),
    );
  }

  // REUSABLE UI PIECES
  Widget _backBtn(bool isMobile) => AnimatedBuilder(
    animation: Listenable.merge([
      adminPasswordRequestNotifier,
      adminDeletionRequestNotifier,
      adminQRReprintNotifier,
      adminFacultyRequestNotifier,
    ]),
    builder: (context, child) {
      final bool hasNotification = (adminPasswordRequestNotifier.value > 0) || 
                                   (adminDeletionRequestNotifier.value > 0) || 
                                   (adminQRReprintNotifier.value > 0) || 
                                   (adminFacultyRequestNotifier.value > 0);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 15), 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new, 
                color: Colors.white, 
                size: isMobile ? 20 : 30
              ),
            ),
          ),
          
          if (hasNotification)
            Positioned(
              right: isMobile ? 0 : 2,
              top: isMobile ? 0 : 2,
              child: Container(
                width: isMobile ? 10 : 20,
                height: isMobile ? 10 : 20,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white, 
                    width: isMobile ? 1.5 : 2 
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _fieldLabel(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      child,
    ],
  );

  Widget _inputBox(String val, {TextEditingController? controller, bool isReadOnly = true, bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller ?? TextEditingController(text: val),
        readOnly: isReadOnly,
        maxLines: 1,
        expands: false,
        scrollPhysics: const BouncingScrollPhysics(),
        textAlignVertical: TextAlignVertical.center,
        
        style: TextStyle(
          color: Colors.white, 
          fontSize: isMobile ? 16 : 20,
          overflow: TextOverflow.visible,
        ),
        
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _dateDisplay(DateTime? date, bool isMobile) {
    String formatted = "----/--/--";
    if (date != null) {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      String time = "${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? "PM" : "AM"}";
      formatted = "${months[date.month - 1]} ${date.day}, ${date.year} | $time";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: Text(formatted, style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20)),
    );
  }

  Widget _largeBox(TextEditingController ctrl, bool isMobile) => Container(
    height: 150, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
    child: TextField(controller: ctrl, readOnly: true, maxLines: null, style: TextStyle(color: Colors.white70, fontSize: isMobile ? 16 : 20), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(10))),
  );

  Widget _statusCard(Map? latest, String time, String date, {bool isMobile = false}) {
    return InkWell(
      onTap: () async {
        final navigator = Navigator.of(context);
        showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E))));
        try {
          final response = await supabase.from('tracking_history').select().eq('document_id', widget.document['document_id']).order('updated_at', ascending: true);
          if (!mounted) return;
          navigator.pop();
          navigator.push(MaterialPageRoute(builder: (context) => FullTrackingHistoryPage(history: List<Map<String, dynamic>>.from(response), document: widget.document)));
        } catch (e) {
          if (mounted) navigator.pop();
        }
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 15 : 25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF78CF4E).withOpacity(0.2), Colors.transparent],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF78CF4E).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Symbols.label, color: const Color(0xFF78CF4E), size: isMobile ? 30 : 40),
            SizedBox(width: isMobile ? 10 : 25),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest?['status'] ?? 'loading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMobile)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              "OFFICE: ${latest?['office'] ?? 'loading...'}",
                              style: TextStyle(color: Colors.white54, fontSize: 8),
                              softWrap: false,
                            ),
                          ),
                        )
                      else
                        Text(
                          "OFFICE: ${latest?['office'] ?? 'loading...'}",
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        ),

                      if (!isMobile)
                        Text(
                          " | $date at $time",
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Row(
              children: [
                const SizedBox(width: 5),
                if (isMobile) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        time,
                        style: const TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF78CF4E)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pos(double l, double t, double? w, double? h, Widget child) => Positioned(left: l, top: t, child: SizedBox(width: w, height: h, child: child));
}