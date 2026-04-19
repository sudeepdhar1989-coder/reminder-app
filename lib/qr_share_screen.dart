import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'reminder_model.dart';

class QRShareScreen extends StatelessWidget {
  final List<Reminder> reminders;

  const QRShareScreen({
    super.key,
    required this.reminders,
  });

  @override
  Widget build(BuildContext context) {
    final data = {
      'type': 'reminder_qr',
      'count': reminders.length,
      'reminders': reminders.map((r) => r.toMap()).toList(),
    };

    final qrData = jsonEncode(data);

    return Scaffold(
      appBar: AppBar(
        title: Text("${reminders.length} Reminders"),
        backgroundColor: Colors.blue,
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            QrImageView(
              data: qrData,
              size: 260,
            ),

            const SizedBox(height: 20),

            Text(
              "Scan to transfer ${reminders.length} reminder(s)",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}