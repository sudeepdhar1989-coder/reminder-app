import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'reminder_model.dart';

class QRScanScreen extends StatefulWidget {
  final Function refreshReminders;

  const QRScanScreen({super.key, required this.refreshReminders});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final NotificationService _notification = NotificationService();

  bool _isProcessing = false;

  Future<void> _importData(String raw) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final Map<String, dynamic> data = jsonDecode(raw);

      if (data['type'] != 'reminder_qr') return;

      final List list = data['reminders'];

      for (var item in list) {
        final reminder = Reminder.fromMap(item);

        await _db.insertReminder(reminder);

        if (reminder.isActive) {
          await _notification.scheduleExactTimeReminder(reminder);
        }
      }

      widget.refreshReminders();

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Imported successfully")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid QR data: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first;

          if (barcode.rawValue != null) {
            _importData(barcode.rawValue!);
          }
        },
      ),
    );
  }
}