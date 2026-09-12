import 'dart:convert';
import 'dart:html' as html; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CsvExport{
  static final supabase = Supabase.instance.client;

  static Future<void> downloadTrackingHistory({
    required String office,
    required DateTimeRange dateRange,
  }) async {
    try {
      var query = supabase.from('tracking_history').select();

      // Base Date Filter
      query = query.gte('updated_at', dateRange.start.toIso8601String());
      query = query.lte('updated_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());

      // Modified Office Logic
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

      if (data.isEmpty) throw "No tracking records found for the selected filters.";

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
      final String cleanOfficeName = office.replaceAll(' ', '_');
      final String fileName = "Tracking_History_Report_${cleanOfficeName}_${startDateStr}_to_$endDateStr.csv";

      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
        
      html.Url.revokeObjectUrl(url);

    } catch (e) {
      debugPrint("Export Error: $e");
      rethrow;
    }
  }
}