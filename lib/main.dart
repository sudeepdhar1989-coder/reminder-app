import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io'; // ✅ ADDED for Platform checks
import 'database_helper.dart';
import 'home_screen.dart';
import 'reminder_model.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize database
  await DatabaseHelper().database;

  // ✅ Handle incoming shares ONLY on Android
  if (Platform.isAndroid) {
    _handleIncomingShares();
  }

  runApp(const ReminderApp());
}

/// ✅ AUTO-IMPORT SHARED REMINDERS (Android-only)
Future<void> _handleIncomingShares() async {
  // Method 1: Handle share intent (Android only)
  const platform = MethodChannel('com.example.reminder_app/share');
  try {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        final String sharedText = call.arguments['text'] ?? '';
        await _processSharedData(sharedText);
      }
    });
  } catch (e) {
    print('ℹ️ Share channel not available: $e');
  }

  // Method 2: Periodic clipboard check (Android fallback)
  _startClipboardListener();
}

Future<void> _processSharedData(String sharedText) async {
  try {
    // Extract JSON from shared text
    final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').firstMatch(sharedText);
    if (jsonMatch == null) return;

    final jsonString = jsonMatch.group(0)!;
    final data = jsonDecode(jsonString);

    final dbHelper = DatabaseHelper();

    if (data['action'] == 'import_reminder') {
      final reminderMap = Map<String, dynamic>.from(data['reminder']);
      final reminder = Reminder.fromMap(reminderMap);
      
      final id = await dbHelper.insertReminder(reminder);
      print('✅ Imported reminder: ${reminder.title} (ID: $id)');
      
      _showImportSuccess('Imported: ${reminder.title}');
      
    } else if (data['action'] == 'import_reminders') {
      final remindersData = data['reminders'] as List;
      int importedCount = 0;
      
      for (final reminderMap in remindersData) {
        final reminder = Reminder.fromMap(Map<String, dynamic>.from(reminderMap));
        await dbHelper.insertReminder(reminder);
        importedCount++;
      }
      
      print('✅ Imported $importedCount reminders');
      _showImportSuccess('Imported $importedCount reminders');
    }
  } catch (e, stack) {
    print('❌ Import error: $e\n$stack');
    _showImportError('Failed to import. Make sure it\'s from Reminder App.');
  }
}

void _startClipboardListener() {
  // Periodic clipboard check (Android fallback)
  Future.delayed(const Duration(seconds: 2), () {
    _checkClipboard();
  });
}

Future<void> _checkClipboard() async {
  final clipboardData = await Clipboard.getData('text/plain');
  if (clipboardData?.text != null) {
    await _processSharedData(clipboardData!.text!);
  }
}

void _showImportSuccess(String message) {
  // ✅ iOS: Use print for now (add global snackbar later)
  print('🎉 $message');
}

void _showImportError(String message) {
  print('❌ $message');
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}