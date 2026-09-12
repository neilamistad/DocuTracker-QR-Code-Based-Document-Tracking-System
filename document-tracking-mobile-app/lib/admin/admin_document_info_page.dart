import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/background_wrapper.dart';

import '../utils/admin_notifications.dart';

import '../full_tracking_history_page.dart';

class AdminDocumentInfoPage extends StatefulWidget {
  final Map<String, dynamic> document;

  const AdminDocumentInfoPage({
    super.key,
    required this.document,
  });

  @override
  State<AdminDocumentInfoPage> createState() => _AdminDocumentInfoPageState();
}

class _AdminDocumentInfoPageState extends State<AdminDocumentInfoPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> trackingHistory = [];
  bool isLoadingHistory = true;
  String? registeredById;
  bool isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    fetchTrackingHistory();
    fetchRegistererId();
  }

  // LOGIC

  Future<void> fetchRegistererId() async {
    try {
      final regId = widget.document['registered_by_id'].toString();

      if (mounted) {
        setState(() {
          registeredById = regId;
          isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingUser = false);
    }
  }

  Future<void> fetchTrackingHistory() async {
    try {
      final response = await supabase
          .from('tracking_history')
          .select()
          .eq('document_id', widget.document['document_id'])
          .order('updated_at', ascending: true);
      
      if (mounted) {
        setState(() {
          trackingHistory = List<Map<String, dynamic>>.from(response);
          isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _navigateToHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullTrackingHistoryPage(
          history: trackingHistory,
          document: widget.document,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime? regDate;
    if (trackingHistory.isNotEmpty) {
      final reg = trackingHistory.firstWhere(
        (item) => item['status'] == 'Registered', 
        orElse: () => trackingHistory.first
      );
      regDate = DateTime.tryParse(reg['updated_at'] ?? "");
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 30, 0, 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _backBtnWithBadge(),
                    ),
                    const Text(
                      'Admin Document Info',
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w800, 
                        color: Colors.white, 
                        fontFamily: 'Noto Sans Hebrew'
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 50),
                  child: Column(
                    children: [
                      const Text(
                        'Administrative view of document metadata and audit logs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 30),
                      _buildMainCard(regDate),
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

  Widget _buildMainCard(DateTime? regDate) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel("DOCUMENT ID", _readOnlyBox(widget.document['document_id'],)),
              const SizedBox(height: 20),
              _fieldLabel("DOCUMENT NAME", _readOnlyBox(widget.document['document_name'],)),
              const SizedBox(height: 20),
              _fieldLabel("REGISTERED BY (USER ID)", _readOnlyBox(
                isLoadingUser ? "Loading..." : (registeredById ?? "N/A"),)),
              const SizedBox(height: 20),

              _fieldLabel("REGISTERED AT", _readOnlyBox(_formatDate(regDate))),
              const SizedBox(height: 20),
              _fieldLabel("TYPE OF DOCUMENT", _readOnlyBox(widget.document['document_type'] ?? "Others")),
              const SizedBox(height: 25),
              _fieldLabel("ADDITIONAL DETAILS", _readOnlyLargeBox(widget.document['details'] ?? "No additional details provided.")),
              const SizedBox(height: 30),
              _fieldLabel("CURRENT TRACKING STATUS", _statusCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('tracking_history')
          .stream(primaryKey: ['history_id'])
          .eq('document_id', widget.document['document_id'])
          .order('updated_at', ascending: false)
          .limit(1),
      builder: (context, snapshot) {
        final latest = (snapshot.hasData && snapshot.data!.isNotEmpty) 
            ? snapshot.data!.first 
            : null;

        String date = "--";
        String time = "--";
        if (latest != null && latest['updated_at'] != null) {
          DateTime dt = DateTime.parse(latest['updated_at']);
          date = DateFormat('MMM dd, yyyy').format(dt).toUpperCase();
          time = DateFormat('hh:mm a').format(dt);
        }

        return InkWell(
          onTap: () async {
            _navigateToHistory();
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF78CF4E).withOpacity(0.2), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF78CF4E).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.label_important_outline_rounded, color: Color(0xFF78CF4E), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest?['status']?.toString().toUpperCase() ?? 'PENDING...',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          "OFFICE: ${latest?['office'] ?? 'N/A'}",
                          style: const TextStyle(
                            color: Colors.white54, 
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(time, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF78CF4E)),
              ],
            ),
          ),
        );
      },
    );
  }

  // UI COMPONENTS
  Widget _fieldLabel(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _readOnlyBox(String text, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white38, size: 16), 
            const SizedBox(width: 10)
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Text(
                text,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyLargeBox(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 80, 
        maxHeight: 200,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Scrollbar(
        thumbVisibility: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backBtnWithBadge() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        adminPasswordRequestNotifier,
        adminDeletionRequestNotifier,
        adminQRReprintNotifier,
        adminFacultyRequestNotifier,
      ]),
      builder: (context, child) {
        final bool hasNotifications = 
            adminPasswordRequestNotifier.value > 0 ||
            adminDeletionRequestNotifier.value > 0 ||
            adminQRReprintNotifier.value > 0 ||
            adminFacultyRequestNotifier.value > 0;

        return Stack(
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
            if (hasNotifications)
              Positioned(
                right: -2, top: -2,
                child: Container(
                  width: 12, height: 12,
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
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "----/--/--";
    return DateFormat('MMM dd, yyyy | hh:mm a').format(date);
  }
}