import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/main.dart';  // ✅ FIXED

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ReminderApp());  // ✅ FIXED

    // Verify that our app shows up
    expect(find.text('Reminders'), findsOneWidget);
  });
}