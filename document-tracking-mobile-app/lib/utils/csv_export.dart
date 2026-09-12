import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvExport {
  static final supabase = Supabase.instance.client;

  static Future<void> downloadTrackingHistory({
    required String office,
    required DateTimeRange dateRange,
  }) async {
    try {
      var query = supabase.from('tracking_history').select();

      // Date Filter
      query = query.gte('updated_at', dateRange.start.toIso8601String());
      query = query.lte('updated_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());

      if (office == 'OCA') {
        query = query.or('office.eq.OCA,and(office.neq.OCA,office.neq.ODI)');
      } 
      else if (office == 'ODI') {
        query = query.or('office.eq.ODI,and(office.neq.OCA,office.neq.ODI)');
      } 
      else if (office == 'Department') {
        query = query.not('office', 'in', '("OCA","ODI")');
      }

      final List<dynamic> data = await query.order('updated_at', ascending: false);

      if (data.isEmpty) throw "No tracking records found.";

      // Manual CSV Conversion
      String csvData = "Document ID,Status,Office,Timestamp,Owner ID,Owner Type\n";
      for (var item in data) {
        String row = [
          item['document_id'],
          item['status'],
          item['office'],
          item['updated_at'].toString().substring(0, 19).replaceAll('T', ' '),
          item['registered_by_id'],
          item['registered_by_type'],
        ].map((e) => '"$e"').join(",");
        csvData += "$row\n";
      }

      final String startDateStr = DateFormat('MMM-dd').format(dateRange.start);
      final String endDateStr = DateFormat('MMM-dd-yyyy').format(dateRange.end);
      final String fileName = "Tracking_History_Report_${office.replaceAll(' ', '_')}_$startDateStr-to-$endDateStr.csv";

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Tracking History Export',
        text: 'Exported tracking history from $startDateStr to $endDateStr',
      );

    } catch (e) {
      debugPrint("Mobile Export Error: $e");
      rethrow;
    }
  }
}