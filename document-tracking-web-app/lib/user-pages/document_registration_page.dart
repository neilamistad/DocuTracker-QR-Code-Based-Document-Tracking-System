import 'dart:ui';
import 'dart:io' as io;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:material_symbols_icons/symbols.dart';

class DocumentRegistrationPage extends StatefulWidget {
  final String userType;
  final String userId;

  const DocumentRegistrationPage({
    super.key,
    required this.userType,
    required this.userId,
  });

  @override
  State<DocumentRegistrationPage> createState() => _DocumentRegistrationPageState();
}

class _DocumentRegistrationPageState extends State<DocumentRegistrationPage> {
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

      // TRACKING HISTORY INSERT
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
      _showTopNotification("Error: ${e.toString()}", Colors.red);
    }
  }

  Future<void> generateQrPdf(String docId) async {
    final pdf = pw.Document();
    
    try {
      // GENERATE QR IMAGE
      final qrImage = await QrPainter(
        data: docId, 
        version: QrVersions.auto, 
        gapless: true
      ).toImageData(300);
      
      if (qrImage == null) throw "QR Generation failed";
      final qrBytes = qrImage.buffer.asUint8List();

      // PDF LAYOUT
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
        build: (context) => pw.Center(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 20 * PdfPageFormat.mm, 
                height: 20 * PdfPageFormat.mm, 
                child: pw.Image(pw.MemoryImage(qrBytes))
              ),
              pw.SizedBox(width: 2 * PdfPageFormat.mm),
              pw.Container(
                width: 24 * PdfPageFormat.mm, 
                child: pw.Text(
                  docId, 
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), 
                  textAlign: pw.TextAlign.center
                )
              ),
            ],
          ),
        ),
      ));

      final bytes = await pdf.save();

      // HYBRID OUTPUT LOGIC
      if (kIsWeb) {
        // FOR WEB/IPHONE (FOR NEW TAB)
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);

        html.AnchorElement(href: url)
          ..setAttribute("download", "$docId.pdf")
          ..target = "_blank" 
          ..click();

        Future.delayed(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
        
      } else {
        // FOR NATIVE DESKTOP
        final io.Directory? downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) throw "Downloads folder not found";

        final String filePath = p.join(downloadsDir.path, "$docId.pdf");
        final io.File file = io.File(filePath);

        await file.writeAsBytes(bytes);
        await OpenFile.open(filePath);
        
        if (mounted) {
          _showTopNotification("Document registered! QR saved to Downloads.", Colors.green);
        }
      }
    } catch (e) {
      debugPrint("Registration QR Error: $e");
      if (mounted) {
        _showTopNotification("Document registered, but QR generation failed.", Colors.orange);
      }
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

  void _showSuccessPopup(String docId) {
    bool isDownloading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF78CF4E), width: 1.5),
              ),
              title: const Text("Success", style: TextStyle(color: Colors.white)),
              content: Text(
                "Document Registered: $docId",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: isDownloading ? null : () => Navigator.pop(context),
                  child: Text(
                    "Close",
                    style: TextStyle(
                      color: isDownloading ? Colors.white10 : Colors.white30,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF418948),
                    minimumSize: const Size(120, 40),
                  ),
                  onPressed: isDownloading
                      ? null
                      : () async {
                          setDialogState(() => isDownloading = true);

                          try {
                            await generateQrPdf(docId);
                          } finally {

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                  child: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text("Download QR", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // UNIFORMED UI DESIGN

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60 : 25, 
            vertical: 40
          ),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: isDesktop ? 5 : 0,
                child: _buildHeroSection(isDesktop),
              ),
              if (isDesktop) const SizedBox(width: 80),
              if (!isDesktop) const SizedBox(height: 50),
              
              Expanded(
                flex: isDesktop ? 6 : 0,
                child: _buildRegistrationCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'Document Registration',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontSize: isDesktop ? 75 : 35, fontFamily: 'Noto Sans Hebrew', fontWeight: FontWeight.bold, height: 1.1, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Input necessary details to generate a unique tracking ID and QR code for your document.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: isDesktop ? 18 : 14, fontWeight: FontWeight.w200),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("DOCUMENT NAME *"),
              _textField(nameCtrl, Symbols.description, "e.g. Request Letter"),
              const SizedBox(height: 25),
              _label("DOCUMENT TYPE *"),
              _dropdown(),
              const SizedBox(height: 25),
              _label("ADDITIONAL DETAILS"),
              _textField(detailCtrl, Symbols.edit_note, "Optional details...", maxLines: 4),
              const SizedBox(height: 40),
              _submitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // REUSABLE COMPONENTS

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 10),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  Widget _textField(TextEditingController ctrl, IconData icon, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF78CF4E)),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedType,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          hint: const Text("Select Type", style: TextStyle(color: Colors.white24)),
          style: const TextStyle(color: Colors.white),
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
      child: Opacity(
        opacity: _isLoading ? 0.7 : 1.0,
        child: Container(
          width: double.infinity,
          height: 60,
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
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ) 
              : const Text(
                  "REGISTER DOCUMENT", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
          ),
        ),
      ),
    );
  }
  
}