import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../widgets/app_background.dart';

import '../utils/other_office_notification_utils.dart';

import 'full_tracking_history_page.dart';

class VerifyDocumentPage extends StatefulWidget {
  final String documentId;
  const VerifyDocumentPage({super.key, required this.documentId});

  @override
  State<VerifyDocumentPage> createState() => _VerifyDocumentPageState();
}

class _VerifyDocumentPageState extends State<VerifyDocumentPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? document;
  List<Map<String, dynamic>> trackingHistory = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchDocumentInfo();
  }

  Future<void> fetchDocumentInfo() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      final docResponse = await supabase.from('documents').select().eq('document_id', widget.documentId).maybeSingle();
      if (docResponse == null) {
        setState(() { errorMsg = "Document not found."; isLoading = false; });
        return;
      }
      final historyResponse = await supabase.from('tracking_history').select().eq('document_id', widget.documentId).order('updated_at', ascending: false);
      setState(() {
        document = Map<String, dynamic>.from(docResponse);
        trackingHistory = List<Map<String, dynamic>>.from(historyResponse);
        isLoading = false;
      });
    } catch (e) {
      setState(() { errorMsg = "Failed to load document info."; isLoading = false; });
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return "--:--";
    DateTime? dt = DateTime.tryParse(raw);
    if (dt == null) return "--:--";
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    String time = "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? "PM" : "AM"}";
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year} | $time";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E)))
          : errorMsg != null 
            ? Center(child: Text(errorMsg!, style: const TextStyle(color: Colors.red)))
            : LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktop = constraints.maxWidth > 1100;
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: isDesktop ? 1920 : constraints.maxWidth,
                        height: isDesktop ? 1080 : constraints.maxHeight,
                        child: isDesktop 
                          ? _buildDesktopLayout() 
                          : _buildMobileLayout(),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        Positioned(left: 60, top: 60, child: _backBtn()),
        _pos(100, 300, 650, null, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document\nInformation', style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white)),
            const SizedBox(height: 30),
            const Text('Detailed verification view of document\nclassification and full audit trail.', style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w200)),
          ],
        )),
        _pos(850, 150, 950, 800, _buildGlassyCard(isMobile: false)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Align(alignment: Alignment.topLeft, child: _backBtn()),
          const SizedBox(height: 20),
          const Text('Document Info', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          Expanded(child: SingleChildScrollView(child: _buildGlassyCard(isMobile: true))),
        ],
      ),
    );
  }

  Widget _buildGlassyCard({required bool isMobile}) {
    final latest = trackingHistory.isNotEmpty ? trackingHistory.first : null;
    double padding = isMobile ? 25 : 60;

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
              Row(
                children: [
                  Expanded(child: _fieldLabel("DOCUMENT ID", _inputBox(document?['document_id'] ?? "-", isMobile))),
                  SizedBox(width: isMobile ? 15 : 40),
                  Expanded(child: _fieldLabel("DOCUMENT NAME", _inputBox(document?['document_name'] ?? "-", isMobile))),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: _fieldLabel("REGISTERED AT", _inputBox(_formatDateTime(document?['registered_at']), isMobile))),
                  SizedBox(width: isMobile ? 15 : 40),
                  Expanded(child: _fieldLabel("TYPE", _inputBox(document?['document_type'] ?? "-", isMobile))),
                ],
              ),
              const SizedBox(height: 30),
              _fieldLabel("ADDITIONAL DETAILS", _largeBox(document?['details'] ?? "No details.", isMobile)),
              const SizedBox(height: 30),
              
              _fieldLabel("REGISTERED BY (USER ID)", _inputBox(document?['registered_by_id']?.toString() ?? "N/A", isMobile)),
              
              const SizedBox(height: 30),
              _fieldLabel("LATEST TRACKING STATUS", _statusCard(latest)),
            ],
          ),
        ),
      ),
    );
  }

  // UI PIECES
  Widget _pos(double l, double t, double? w, double? h, Widget child) => Positioned(left: l, top: t, child: SizedBox(width: w, height: h, child: child));

  Widget _backBtn() => ValueListenableBuilder<int>(
    valueListenable: reprintBadgeNotifier,
    builder: (context, badgeCount, child) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), 
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new, 
                color: Colors.white, 
                size: 30,
              ),
            ),
          ),

          if (badgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 14,
                height: 14,
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
  );

  Widget _fieldLabel(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      child,
    ],
  );

  Widget _inputBox(String val, bool isMobile) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
    child: Text(val, style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20)),
  );

  Widget _largeBox(String val, bool isMobile) => Container(
    width: double.infinity, height: 120,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
    child: SingleChildScrollView(child: Text(val, style: TextStyle(color: Colors.white70, fontSize: isMobile ? 16 : 20))),
  );

  Widget _statusCard(Map? latest) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullTrackingHistoryPage(history: trackingHistory, document: document))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF78CF4E).withOpacity(0.2), Colors.transparent]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF78CF4E).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Symbols.analytics, color: Color(0xFF78CF4E), size: 40),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latest?['status'] ?? 'Registered', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("OFFICE: ${latest?['office'] ?? 'Main Office'} • ${_formatDateTime(latest?['updated_at'])}", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF78CF4E)),
          ],
        ),
      ),
    );
  }
}