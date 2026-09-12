import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AccountApprovalEmailService {
  static Future<void> sendAccountApprovalEmail({
    required String email,
    required String firstName,
    required String facultyId,
  }) async {
    final String formattedDate = DateFormat('MMM dd,yyyy | hh:mm:ss a').format(DateTime.now());

    final Map<String, dynamic> data = {
      'service_id': 'service_7h7y6ws',
      'template_id': 'template_mboie8h',
      'user_id': 'XkKYNLXEE765kniAK',
      'template_params': {
        'to_email': email,
        'to_name': firstName,
        'faculty_id': facultyId,
        'approval_date': formattedDate,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        print("Email sent successfully!");
      } else {
        print("Failed to send email. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("Error sending email: $e");
    }
  }
}