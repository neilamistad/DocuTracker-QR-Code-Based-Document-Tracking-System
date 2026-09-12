import 'dart:ui';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as p;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../widgets/app_background.dart';

import '../utils/notification_utils.dart';

import '../pages/full_tracking_history_page.dart';

class DocumentInfoPage extends StatefulWidget {
  final Map<String, dynamic> document;
  final String userType;
  final String userId;

  const DocumentInfoPage({
    super.key,
    required this.document,
    required this.userId,
    required this.userType,
  });

  @override
  State<DocumentInfoPage> createState() => _DocumentInfoPageState();
}

class _DocumentInfoPageState extends State<DocumentInfoPage> {
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
      final now = DateTime.now().toIso8601String();

      await supabase.from('documents').update({
        'current_status': 'Received Back',
      }).eq('document_id', docId);

      await supabase.from('tracking_history').insert({
        'document_id': docId,
        'status': 'Received Back',
        'office': 'Department of Engineering',
        'registered_by_id': widget.userId,
        'registered_by_type': widget.userType,
        'is_read' : true,
        'updated_at': now,
      });

      await fetchTrackingHistory();
      
      if (mounted) {
        _showTopNotification("The document marked as \"Recieved Back\"", Colors.green);
      }
    } catch (e) {
      debugPrint("Error in Received Back: $e");
    } finally {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> handleRevertReceived(dynamic historyId) async {
    setState(() => isLoadingHistory = true);
    try {
      final int cleanHistoryId = (historyId is String) ? int.parse(historyId) : historyId;

      await supabase.rpc(
        'revert_received_back', 
        params: {'target_history_id': cleanHistoryId}
      );

      await fetchTrackingHistory();
      
      if (mounted) {
        _showTopNotification("Action reverted and status restored.", Colors.orange);
      }
    } catch (e) {
      debugPrint("Revert Error: $e");
      _showTopNotification("Failed to revert: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> generateQrPdf() async {
    final docId = widget.document['document_id']; 
    final pdf = pw.Document();
    
    try {
      final qrImage = await QrPainter(
        data: docId, 
        version: QrVersions.auto, 
        gapless: true
      ).toImageData(300);
      
      if (qrImage == null) throw "Failed to generate QR Image";
      final qrBytes = qrImage.buffer.asUint8List();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Center(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(pw.MemoryImage(qrBytes), width: 20 * PdfPageFormat.mm),
              pw.SizedBox(width: 2 * PdfPageFormat.mm),
              pw.Text(
                docId, 
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)
              ),
            ],
          ),
        ),
      ));

      final bytes = await pdf.save();

      // HYBRID PLATFORM
      if (kIsWeb) {
        // WEB / IPHONE SOLUTION
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);

        html.AnchorElement(href: url)
          ..setAttribute("download", "$docId.pdf") // DOCUMENT ID AS FILENAME
          ..target = "_blank" // OPENS IN NEW TAB
          ..click();

        Future.delayed(const Duration(seconds: 30), () {
          html.Url.revokeObjectUrl(url);
        });
        
      } else {
        // NATIVE DESKTOP SOLUTION (Windows/macOS)
        final io.Directory? downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) throw "Could not access Downloads directory";

        final String filePath = p.join(downloadsDir.path, "$docId.pdf");
        final io.File file = io.File(filePath);

        await file.writeAsBytes(bytes);

        await OpenFile.open(filePath);
        
        if (mounted) {
          _showTopNotification("QR Code saved to Downloads", Colors.green);
        }
      }
    } catch (e) {
      debugPrint("Error generating QR PDF: $e");
      if (mounted) {
        _showTopNotification("Error: Could not generate QR", Colors.red);
      }
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
  }

  void showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 1.5)),
          title: const Text("Request Deletion", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to request deletion of this document? This requires admin approval.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () { Navigator.pop(context); submitDeleteRequest(); },
              child: const Text("Request Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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

  void showReceivedBackConfirmation() {
    bool isRevert = latestStatus == "RECEIVED BACK";

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isRevert ? Colors.redAccent : const Color(0xFF51AC80), width: 1.5)
          ),
          title: Text(isRevert ? "Revert Status?" : "Confirm Receipt", style: const TextStyle(color: Colors.white)),
          content: Text(
            isRevert 
              ? "This will delete the 'Received Back' record and return to the previous status. Proceed?"
              : "Are you sure you have received the document back? This will finalize the current tracking history.",
            style: const TextStyle(color: Colors.white70),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRevert ? Colors.redAccent : const Color(0xFF51AC80),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                if (isRevert) {
                  final res = await supabase
                      .from('tracking_history')
                      .select('history_id')
                      .eq('document_id', widget.document['document_id'])
                      .eq('status', 'Received Back')
                      .order('updated_at', ascending: false)
                      .limit(1)
                      .maybeSingle();
                  
                  if (res != null) {
                    handleRevertReceived(res['history_id'].toString());
                  }
                } else {
                  handleReceivedBack();
                }
              },
              child: Text(isRevert ? "Revert" : "Confirm", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void showDownloadConfirmation(String docId) {
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.orangeAccent, width: 1),
            ),
            title: const Text("Download QR Code", style: TextStyle(color: Colors.white)),
            content: Text("Do you want to generate and download the QR code for $docId?",
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.white30)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent.withOpacity(0.8)),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        try {
                          await generateQrPdf();
                        } finally {
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                child: isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Download", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
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
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isDesktop = constraints.maxWidth > 1100;
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: isDesktop ? 1920 : constraints.maxWidth,
                  height: isDesktop ? 1080 : constraints.maxHeight,
                  child: isDesktop 
                    ? _buildDesktopLayout(latest, currentTime, currentDate, regDate)
                    : _buildMobileLayout(latest, currentTime, currentDate, regDate),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // DESKTOP LAYOUT (1920x1080 Scale)
  Widget _buildDesktopLayout(Map? latest, String time, String date, DateTime? regDate) {
    return Stack(
      children: [
        Positioned(
          left: 60, top: 60,
          child: _backBtn(false),
        ),
        _pos(100, 300, 650, null, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document\nInformation', style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white)),
            const SizedBox(height: 30),
            const Text('Detailed overview of classification, tracking status,\nand official registration records.', 
              style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w200)),
          ],
        )),
        _pos(850, 150, 950, 850, _buildGlassyCard(latest, time, date, regDate, false)),
      ],
    );
  }

  // MOBILE LAYOUT
  Widget _buildMobileLayout(Map? latest, String time, String date, DateTime? regDate) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 10),
          color: Colors.transparent,
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

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                const Text(
                  'Detailed overview of classification, tracking status, and official registration records.',
                  textAlign: TextAlign.left,
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
    double padding = isMobile ? 25 : 60;
    bool isReceived = latestStatus == "RECEIVED BACK";

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
                      const SizedBox(height: 20),
                      _fieldLabel("DOCUMENT NAME", _inputBox("", controller: nameCtrl, isEditable: isEditing, isMobile: isMobile)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _fieldLabel("DOCUMENT ID", _inputBox(widget.document['document_id'], isReadOnly: true, isMobile: isMobile))),
                      const SizedBox(width: 40),
                      Expanded(child: _fieldLabel("DOCUMENT NAME", _inputBox("", controller: nameCtrl, isEditable: isEditing, isMobile: isMobile))),
                    ],
                  ),
              const SizedBox(height: 30),
              isMobile
                ? Column(
                    children: [
                      _fieldLabel("REGISTERED AT", _dateDisplay(regDate, isMobile)),
                      const SizedBox(height: 20),
                      _fieldLabel("TYPE OF DOCUMENT", _dropdownBox(isMobile)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _fieldLabel("REGISTERED AT", _dateDisplay(regDate, isMobile))),
                      const SizedBox(width: 40),
                      Expanded(child: _fieldLabel("TYPE OF DOCUMENT", _dropdownBox(isMobile))),
                    ],
                  ),
              const SizedBox(height: 30),
              _fieldLabel("ADDITIONAL DETAILS", _largeBox(detailsCtrl, isEditing, isMobile)),
              const SizedBox(height: 40),
              _fieldLabel("CURRENT TRACKING STATUS", _statusCard(latest, time, date, isMobile)),
              
              if (!isMobile) const Spacer(),
              const SizedBox(height: 20),

              Center(
                child: isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _actionBtn(
                                  isEditing ? "SAVE" : "EDIT",
                                  isEditing ? Symbols.save : Symbols.edit,
                                  isEditing ? saveChanges : () => setState(() => isEditing = true),
                                  const Color(0xFF78CF4E),
                                  isMobile,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _actionBtn(
                                  "QR", 
                                  Icons.download_outlined, 
                                  () => showDownloadConfirmation(widget.document['document_id']),
                                  Colors.orangeAccent, 
                                  isMobile
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [

                              Expanded(
                                child: _actionBtn(
                                  isReceived ? "REVERT" : "RECEIVED",
                                  isReceived ? Symbols.undo : Symbols.assignment_return,
                                  showReceivedBackConfirmation,
                                  isReceived ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF51AC80).withOpacity(0.8),
                                  isMobile,
                                ),
                              ),
                              const SizedBox(width: 15),

                              Expanded(
                                child: _actionBtn(
                                  hasPendingDeleteRequest ? "PENDING" : "DELETE",
                                  Symbols.delete,
                                  hasPendingDeleteRequest ? null : showDeleteConfirmation,
                                  Colors.redAccent.withOpacity(0.8),
                                  isMobile,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          _actionBtn(isEditing ? "SAVE" : "EDIT", isEditing ? Symbols.save : Symbols.edit, isEditing ? saveChanges : () => setState(() => isEditing = true), const Color(0xFF78CF4E), isMobile),
                          _actionBtn("QR", Icons.download_outlined, () => showDownloadConfirmation(widget.document['document_id']), Colors.orangeAccent, isMobile),
                          _actionBtn(isReceived ? "REVERT RECEIVED" : "RECEIVED BACK", isReceived ? Symbols.undo : Symbols.assignment_return, showReceivedBackConfirmation, isReceived ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF51AC80).withOpacity(0.8), isMobile),
                          _actionBtn(hasPendingDeleteRequest ? "PENDING" : "DELETE", Symbols.delete, hasPendingDeleteRequest ? null : showDeleteConfirmation, Colors.redAccent.withOpacity(0.8), isMobile),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backBtn(bool isMobile) => AnimatedBuilder(
    
    animation: Listenable.merge([
      trackingBadgeNotifier, 
      deletionBadgeNotifier, 
      passwordRequestStatusNotifier
    ]),
    builder: (context, child) {

      final passwordData = passwordRequestStatusNotifier.value;
      
      final bool hasUnreadPassword = passwordData != null && 
                                     passwordData['is_read_user'] == false && 
                                     passwordData['status'] != 'pending';

      final bool hasNotification = (trackingBadgeNotifier.value > 0) || 
                                   (deletionBadgeNotifier.value > 0) || 
                                   hasUnreadPassword;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 15),
              decoration: BoxDecoration( 
                shape: BoxShape.circle
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: isMobile ? 20 : 30),
            ),
          ),
          
          // RED DOT BADGE
          if (hasNotification)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 15,
                height: 15,
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
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      child,
    ],
  );

  Widget _inputBox(String val, {TextEditingController? controller, bool isReadOnly = false, bool isEditable = false, bool isMobile = false}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(15),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: IntrinsicWidth(
          child: TextField(
            controller: controller ?? TextEditingController(text: val),
            readOnly: isReadOnly || !isEditing,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white, 
              fontSize: isMobile ? 16 : 20,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
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

  Widget _dropdownBox(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedType, dropdownColor: const Color(0xFF1A1A1A), isExpanded: true,
          style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 20),
          items: documentTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: isEditing ? (v) => setState(() => selectedType = v) : null,
        ),
      ),
    );
  }

  Widget _largeBox(TextEditingController ctrl, bool edit, bool isMobile) => Container(
    height: 150, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
    child: TextField(controller: ctrl, readOnly: !edit, maxLines: null, style: TextStyle(color: Colors.white70, fontSize: isMobile ? 16 : 20), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(10))),
  );

  Widget _statusCard(Map? latest, String time, String date, bool isMobile) {
    return InkWell(
      onTap: () async {
        final navigator = Navigator.of(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF78CF4E)),
          ),
        );

        try {
          final response = await supabase
              .from('tracking_history')
              .select()
              .eq('document_id', widget.document['document_id'])
              .order('updated_at', ascending: true);

          if (!mounted) return;
          navigator.pop();

          navigator.push(
            MaterialPageRoute(
              builder: (context) => FullTrackingHistoryPage(
                history: List<Map<String, dynamic>>.from(response),
                document: widget.document,
              ),
            ),
          );
        } catch (e) {
          if (mounted) navigator.pop();
          debugPrint("Error navigating to history: $e");
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

  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap, Color color, bool isMobile) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: isMobile ? 15 : 20),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          letterSpacing: 1,
          fontSize: isMobile ? 11 : 18,
        )
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 35, 
          vertical: isMobile ? 20 : 25
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _pos(double l, double t, double? w, double? h, Widget child) => Positioned(left: l, top: t, child: SizedBox(width: w, height: h, child: child));
}