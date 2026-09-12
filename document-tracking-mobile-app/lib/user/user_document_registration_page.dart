import 'dart:ui';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/background_wrapper.dart';

class UserDocumentRegistrationPage extends StatefulWidget {
  final String userType;
  final String userId;

  const UserDocumentRegistrationPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<UserDocumentRegistrationPage> createState() => _UserDocumentRegistrationPageState();
}

class _UserDocumentRegistrationPageState extends State<UserDocumentRegistrationPage> {
  final nameCtrl = TextEditingController();
  final detailCtrl = TextEditingController();
  String? selectedType;
  bool _isLoading = false;

  final List<String> documentTypes = ["Memorandum", "Letter", "Clearance", "Report", "Certificate", "Others"];
  final supabase = Supabase.instance.client;

  Future<void> submit() async {
    if (nameCtrl.text.trim().isEmpty || selectedType == null) {
      _showTopNotification("Please fill in all required fields (Name and Type)", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    String docId = "";
    bool inserted = false;

    try {
      while (!inserted) {
        docId = "ENG-${DateTime.now().year}-${const Uuid().v4().substring(0, 6).toUpperCase()}";
        try {
          await supabase.from('documents').insert({
            'document_id': docId,
            'document_name': nameCtrl.text.trim(),
            'details': detailCtrl.text.trim(),
            'document_type': selectedType,
            'registered_by_id': widget.userId,
            'registered_by_type': widget.userType.toLowerCase(),
            'current_status': 'Registered',
            'registered_at': DateTime.now().toIso8601String(),
          });
          inserted = true;
        } catch (e) {
          if (!e.toString().contains('duplicate key value')) rethrow;
        }
      }

      await supabase.from('tracking_history').insert({
        'document_id': docId,
        'status': 'Registered',
        'office': 'Department of Engineering',
        'registered_by_id': widget.userId,
        'registered_by_type': widget.userType.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      nameCtrl.clear();
      detailCtrl.clear();
      setState(() {
        selectedType = null;
        _isLoading = false;
      });

      _showSuccessPopup(docId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showTopNotification("Database Error: ${e.toString()}", Colors.red);
    }
  }

  Future<void> generateQrPdf(String docId) async {
    final pdf = pw.Document();
    
    try {

      final qrValidationResult = QrValidator.validate(
        data: docId,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) throw "QR Validation failed";

      final qrPainter = QrPainter.withQr(
        qr: qrValidationResult.qrCode!,
        gapless: true,
      );

      final imageData = await qrPainter.toImageData(300);
      if (imageData == null) throw "QR Data failed";
      final qrBytes = imageData.buffer.asUint8List();

      pdf.addPage(pw.Page(
        pageFormat: const PdfPageFormat(60 * PdfPageFormat.mm, 40 * PdfPageFormat.mm),
        build: (context) => pw.Center(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 25 * PdfPageFormat.mm, 
                height: 25 * PdfPageFormat.mm, 
                child: pw.Image(pw.MemoryImage(qrBytes))
              ),
              pw.SizedBox(width: 4 * PdfPageFormat.mm),
              pw.Flexible(
                child: pw.Text(
                  docId, 
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), 
                  textAlign: pw.TextAlign.center
                )
              ),
            ],
          ),
        ),
      ));

      final bytes = await pdf.save();

      final io.Directory tempDir = await getTemporaryDirectory();
      final String filePath = p.join(tempDir.path, "$docId.pdf");
      final io.File file = io.File(filePath);

      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done && mounted) {
        _showTopNotification("Could not open PDF: ${result.message}", Colors.orange);
      }
    } catch (e) {
      debugPrint("QR Generation Error: $e");
      if (mounted) _showTopNotification("QR generation failed.", Colors.orange);
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

  void _showSuccessPopup(String docId) {
    bool isDownloading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: const BorderSide(color: Color(0xFF78CF4E), width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF78CF4E)),
                  SizedBox(width: 10),
                  Text("Registered", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Text(
                "ID: $docId\n\nYour document is now in the system. Please download and print the QR label.",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: isDownloading ? null : () => Navigator.pop(context),
                  child: Text("Later", style: TextStyle(color: isDownloading ? Colors.white10 : Colors.white38)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF418948),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isDownloading ? null : () async {
                    setDialogState(() => isDownloading = true);
                    try {
                      await generateQrPdf(docId);
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: isDownloading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Download QR", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        resizeToAvoidBottomInset: true, 
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false, 
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(25, 50, 25, 20),
            child: Column(
              children: [
                _buildHeroSection(),
                const SizedBox(height: 40),
                _buildRegistrationCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        const Text(
          'Document Registration',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32, 
            fontWeight: FontWeight.bold, 
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fill in the details to generate your unique tracking ID and QR code label.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label("DOCUMENT NAME *"),
                _textField(nameCtrl, Symbols.description, "Enter document name"),
                const SizedBox(height: 25),
                _label("DOCUMENT TYPE *"),
                _dropdown(),
                const SizedBox(height: 25),
                _label("ADDITIONAL DETAILS"),
                _textField(detailCtrl, Symbols.edit_note, "Optional details...", maxLines: 3),
                const SizedBox(height: 35),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );

  Widget _textField(TextEditingController ctrl, IconData icon, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF78CF4E), size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedType,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          hint: const Text("Select Type", style: TextStyle(color: Colors.white24, fontSize: 14)),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => selectedType = v),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return InkWell(
      onTap: _isLoading ? null : submit, 
      borderRadius: BorderRadius.circular(15),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isLoading ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.fromARGB(255, 4, 76, 69),
              Color.fromARGB(255, 119, 150, 52),
              Color.fromARGB(255, 10, 99, 56),
            ],
          ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (!_isLoading) 
                BoxShadow(color: const Color(0xFF78CF4E).withOpacity(0.2), offset: const Offset(0, 0))
            ],
          ),
          child: Center(
            child: _isLoading 
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("REGISTER DOCUMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ),
        ),
      ),
    );
  }
}