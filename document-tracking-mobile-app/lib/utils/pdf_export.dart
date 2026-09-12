import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class PdfExport {
  static final supabase = Supabase.instance.client;

  static Future<void> downloadTrackingPdf({
    required String office,
    required DateTimeRange dateRange,
  }) async {
    try {
      // Query Data
      var query = supabase.from('tracking_history').select();
      query = query.gte('updated_at', dateRange.start.toIso8601String());
      query = query.lte('updated_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());

      if (office == 'OCA') {
        query = query.or('office.eq.OCA,and(office.neq.OCA,office.neq.ODI)');
      } else if (office == 'ODI') {
        query = query.or('office.eq.ODI,and(office.neq.OCA,office.neq.ODI)');
      } else if (office == 'Department') {
        query = query.not('office', 'in', '("OCA","ODI")');
      }

      final List<dynamic> data = await query.order('updated_at', ascending: false);
      if (data.isEmpty) throw "No records found.";

      // Create PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text("TRACKING HISTORY REPORT", 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text("Category: $office"),
            pw.Text("Period: ${DateFormat('MMM dd, yyyy').format(dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange.end)}"),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              headers: ['Timestamp', 'Doc ID', 'Status', 'Office', 'Owner ID', 'Owner type'],
              data: data.map((item) => [
                item['updated_at'].toString().substring(0, 19).replaceAll('T', ' '),
                item['document_id'],
                item['status'],
                item['office'],
                item['registered_by_id'],
                item['registered_by_type'],
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
            ),
          ],
        ),
      );

      // Mobile Save and Open Logic
      final bytes = await pdf.save();
      
      final directory = await getApplicationDocumentsDirectory();
      
      final String startDateStr = DateFormat('MMMdd').format(dateRange.start);
      final String endDateStr = DateFormat('MMMdd').format(dateRange.end);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "Tracking_History_Report_${office}_$startDateStr-${endDateStr}_$timestamp.pdf";
      
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(bytes);

      await OpenFilex.open(file.path);

    } catch (e) {
      debugPrint("Mobile PDF Error: $e");
      rethrow;
    }
  }
}