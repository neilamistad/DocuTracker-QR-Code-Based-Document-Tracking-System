import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PasswordUpdateEmailService {
  static Future<void> sendPasswordStatusEmail({
    required String email,
    required String status,
  }) async {
    final String formattedDate = DateFormat('MMM dd, yyyy | hh:mm:ss a').format(DateTime.now());

    final Map<String, dynamic> data = {
      'service_id': 'service_7h7y6ws',
      'template_id': 'template_3nmnfux', 
      'user_id': 'XkKYNLXEE765kniAK',
      'accessToken': 'hC3-_JOv9bfUGJQ3CUNFG',
      'template_params': {
        'to_email': email,
        'to_name': email.split('@')[0],
        'status': status,
        'date': formattedDate,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        debugPrint("Password status email sent: $status to $email");
      } else {
        debugPrint("EmailJS Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("Network Error in PasswordService: $e");
    }
  }
}