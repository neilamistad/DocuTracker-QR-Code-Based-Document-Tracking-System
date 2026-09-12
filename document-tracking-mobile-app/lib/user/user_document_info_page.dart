import 'dart:ui';
import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/background_wrapper.dart';
import '../utils/user_notifications.dart';
import '../full_tracking_history_page.dart';

class UserDocumentInfoPage extends StatefulWidget {
  final Map<String, dynamic> document;
  final String userType;
  final String userId;

  const UserDocumentInfoPage({
    super.key,
    required this.document,
    required this.userId,
    required this.userType,
  });

  @override
  State<UserDocumentInfoPage> createState() => _UserDocumentInfoPageState();
}

class _UserDocumentInfoPageState extends State<UserDocumentInfoPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController nameCtrl;
  late TextEditingController detailsCtrl;
  String? selectedType;

  String get latestStatus => trackingHistory.isNotEmpty 
    ? trackingHistory.last['status'].toString().toUpperCase() 
    : "";

  bool isEditing = false;
  List<Map<String, dynamic>> trackingHistory = [];
  bool isLoadingHistory = true;
  bool hasPendingDeleteRequest = false;
  bool isSubmittingDelete = false;

  final documentTypes = ["Memorandum", "Letter", "Clearance", "Report", "Certificate", "Others"];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.document['document_name']);
    detailsCtrl = TextEditingController(text: widget.document['details'] ?? '');
    selectedType = widget.document['document_type'];
    fetchTrackingHistory();
    checkPendingDeleteRequest();
  }

  // LOGIC FUNCTIONS
  Future<void> checkPendingDeleteRequest() async {
    final res = await supabase.from('document_deletion_requests').select('id').eq('document_id', widget.document['document_id']).eq('status', 'pending').maybeSingle();
    setState(() => hasPendingDeleteRequest = res != null);
  }

  Future<void> submitDeleteRequest() async {
    setState(() => isSubmittingDelete = true);
    try {
      await supabase.from('document_deletion_requests').insert({
        'document_id': widget.document['document_id'],
        'document_name': widget.document['document_name'],
        'requested_by': widget.userId.toString(),
        'requested_by_usertype': widget.userType.toString(),
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      setState(() => hasPendingDeleteRequest = true);
      _showTopNotification("Deletion request submitted.", Colors.orange);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isSubmittingDelete = false);
    }
  }

  Future<void> handleReceivedBack() async {
    setState(() => isLoadingHistory = true);
    try {
      final docId = widget.document['document_id'];
      await supabase.from('documents').update({'current_status': 'Received Back'}).eq('document_id', docId);
      await supabase.from('tracking_history').insert({
        'document_id': docId,
        'status': 'Received Back',
        'office': 'Department of Engineering',
        'registered_by_id': widget.userId,
        'registered_by_type': widget.userType,
        'is_read' : true,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await fetchTrackingHistory();
      _showTopNotification("The document marked as \"Received Back\"", Colors.green);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> handleRevertReceived(dynamic historyId) async {

    setState(() => isLoadingHistory = true);
    try {

      final int cleanHistoryId = (historyId is String) 
          ? int.parse(historyId) 
          : (historyId as int);

      await supabase.rpc(
        'revert_received_back', 
        params: {'target_history_id': cleanHistoryId}
      );

      await fetchTrackingHistory();
      _showTopNotification("Action reverted.", Colors.orange);
    } catch (e) {
      debugPrint("Failed to revert: $e");
      _showTopNotification("Failed to revert: $e", Colors.red);
    } finally {
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> generateQrPdf() async {
    final docId = widget.document['document_id'];
    final pdf = pw.Document();

    try {

      final qrImage = await QrPainter(
        data: docId,
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(300);

      if (qrImage == null) throw "Failed to generate QR";
      final qrBytes = qrImage.buffer.asUint8List();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Center(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Image(pw.MemoryImage(qrBytes), width: 20 * PdfPageFormat.mm),
              pw.SizedBox(width: 2 * PdfPageFormat.mm),
              pw.Text(docId, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ));

      final bytes = await pdf.save();

      final io.Directory? downloadsDir = await getExternalStorageDirectory();
      final String filePath = p.join(downloadsDir!.path, "$docId.pdf");
      final io.File file = io.File(filePath);
      
      await file.writeAsBytes(bytes);

      await OpenFilex.open(filePath);
      
      _showTopNotification("QR Code PDF generated and saved.", Colors.green);
    } catch (e) {
      _showTopNotification("QR Error: $e", Colors.red);
      debugPrint("QR Generation Error: $e");
    }
  }

  Future<void> fetchTrackingHistory() async {
    try {
      final response = await supabase.from('tracking_history').select().eq('document_id', widget.document['document_id']).order('updated_at', ascending: true);
      setState(() { trackingHistory = List<Map<String, dynamic>>.from(response); isLoadingHistory = false; });
    } catch (e) { setState(() => isLoadingHistory = false); }
  }

  Future<void> saveChanges() async {
    await supabase.from('documents').update({
      'document_name': nameCtrl.text,
      'document_type': selectedType,
      'details': detailsCtrl.text
    }).eq('document_id', widget.document['document_id']);
    setState(() {
      isEditing = false;
      widget.document['document_name'] = nameCtrl.text;
      widget.document['document_type'] = selectedType;
      widget.document['details'] = detailsCtrl.text;
    });
    _showTopNotification("Changes saved successfully!", Colors.green);
  }

  Future<void> _navigateToHistory() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF78CF4E))),
    );

    try {
      final response = await supabase
          .from('tracking_history')
          .select()
          .eq('document_id', widget.document['document_id'])
          .order('updated_at', ascending: true);

      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullTrackingHistoryPage(
              history: List<Map<String, dynamic>>.from(response),
              document: widget.document,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Navigation Error: $e");
    }
  }

  // HELPER: SHOW TOP SNACKBAR
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

  void showToggleReceivedConfirmation() {
    final bool isRevert = latestStatus == "RECEIVED BACK";

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isRevert ? Colors.redAccent : const Color(0xFF51AC80), 
              width: 1.5
            )
          ),
          title: Text(
            isRevert ? "Revert Status?" : "Confirm Receipt", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          content: Text(
            isRevert 
              ? "This will delete the 'Received Back' record and restore the previous tracking status. Proceed?"
              : "Are you sure you have received this document back? This will add a 'Received Back' entry to the history.",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRevert ? Colors.redAccent : const Color(0xFF51AC80),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                if (isRevert) {
                  final lastId = trackingHistory.last['history_id'];
                  handleRevertReceived(lastId);
                } else {
                  handleReceivedBack();
                }
              },
              child: Text(
                isRevert ? "Revert" : "Confirm", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showDeleteRequestConfirmation() {
    if (hasPendingDeleteRequest) return;

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 1.5)
          ),
          title: const Row(
            children: [
              Icon(Symbols.delete_forever, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Request Deletion", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "Are you sure you want to request the deletion of this document? This action requires Admin approval before it is permanently removed.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                submitDeleteRequest();
              },
              child: const Text("Request Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = trackingHistory.isNotEmpty ? trackingHistory.last : null;
    DateTime? regDate;
    
    if (trackingHistory.isNotEmpty) {
      final reg = trackingHistory.firstWhere(
        (item) => item['status'] == 'Registered', 
        orElse: () => trackingHistory.first
      );
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 30, 10, 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _backBtn(),
                    ),
                    const Text(
                      'Document Info',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Noto Sans Hebrew',
                        letterSpacing: -0.5,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Detailed overview of classification, tracking status, and records.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      _buildGlassyCard(latest, currentTime, currentDate, regDate),
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


  Widget _buildGlassyCard(Map? latest, String time, String date, DateTime? regDate) {
    bool isReceived = latestStatus == "RECEIVED BACK";

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
              _fieldLabel("DOCUMENT ID", _inputBox(widget.document['document_id'], isReadOnly: true)),
              const SizedBox(height: 20),
              _fieldLabel("DOCUMENT NAME", _inputBox("", controller: nameCtrl, isEditable: isEditing)),
              const SizedBox(height: 20),
              _fieldLabel("REGISTERED AT", _dateDisplay(regDate)),
              const SizedBox(height: 20),
              _fieldLabel("TYPE OF DOCUMENT", _dropdownBox()),
              const SizedBox(height: 25),
              _fieldLabel("ADDITIONAL DETAILS", _largeBox(detailsCtrl, isEditing)),
              const SizedBox(height: 30),
              _fieldLabel("CURRENT TRACKING STATUS", _statusCard()),
              const SizedBox(height: 35),

              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _actionBtn(isEditing ? "SAVE" : "EDIT", isEditing ? Symbols.save : Symbols.edit, isEditing ? saveChanges : () => setState(() => isEditing = true), const Color(0xFF78CF4E))),
                      const SizedBox(width: 12),
                      Expanded(child: _actionBtn("QR", Icons.download_outlined, () => generateQrPdf(), Colors.orangeAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                          isReceived ? "REVERT" : "RECEIVED", 
                          isReceived ? Icons.undo_outlined : Icons.assignment_return_outlined, 
                          () => showToggleReceivedConfirmation(), 
                          isReceived 
                              ? Colors.redAccent.withOpacity(0.8) 
                              : const Color(0xFF51AC80).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionBtn(
                          hasPendingDeleteRequest ? "PENDING" : "DELETE", 
                          Symbols.delete, 
                          hasPendingDeleteRequest ? null : () => showDeleteRequestConfirmation(), 
                          Colors.redAccent.withOpacity(hasPendingDeleteRequest ? 0.4 : 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _fieldLabel(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      child,
    ],
  );

  Widget _inputBox(String val, {TextEditingController? controller, bool isReadOnly = false, bool isEditable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isEditing && !isReadOnly) ? Colors.white.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: TextField(
        controller: controller ?? TextEditingController(text: val),
        readOnly: isReadOnly || !isEditing,
        maxLines: 1,
        cursorColor: const Color(0xFF78CF4E),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none, 
          isDense: true,
          hintText: "Enter text...",
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
        ),
      ),
    );
  }

  Widget _dateDisplay(DateTime? date) {
    String formatted = "----/--/--";
    if (date != null) {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      String time = "${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? "PM" : "AM"}";
      formatted = "${months[date.month - 1]} ${date.day}, ${date.year} | $time";
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Text(formatted, style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }

  Widget _backBtn() => ListenableBuilder(
    listenable: Listenable.merge([
      trackingBadgeNotifier,
      deletionBadgeNotifier,
      passwordRequestStatusNotifier,
    ]),
    builder: (context, child) {
      final bool hasCounts = trackingBadgeNotifier.value > 0 || deletionBadgeNotifier.value > 0;
      final passwordData = passwordRequestStatusNotifier.value;
      final bool hasUnreadPassword = passwordData != null &&
          passwordData['is_read_user'] == false &&
          passwordData['status'] != 'pending';

      final bool showRedDot = hasCounts || hasUnreadPassword;

      return IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Stack(
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
                right: -2,
                top: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _largeBox(TextEditingController ctrl, bool edit) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 100,
        maxHeight: 200, 
      ),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: edit ? Colors.white.withOpacity(0.2) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Scrollbar(
        thumbVisibility: false,
        child: TextField(
          controller: ctrl,
          readOnly: !edit,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          decoration: const InputDecoration(
            border: InputBorder.none, 
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            hintText: "Enter additional details...",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _dropdownBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? Colors.white.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedType,
          dropdownColor: const Color(0xFF1A1A1A),
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down_circle_outlined, 
            color: isEditing ? const Color(0xFF78CF4E) : Colors.white24,
            size: 20,
          ),
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 15,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: isEditing ? (v) => setState(() => selectedType = v) : null,
          items: documentTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Text(
                  type,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}