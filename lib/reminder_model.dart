import 'dart:math' as math;

class Reminder {
  int? id;
  final String title;
  final DateTime dateTime;  // ✅ ONLY ONE DECLARATION (Line 6)
  final String? notes;
  final String type;
  final String frequency;
  bool isActive;
  final DateTime createdAt;

  // ✅ Backward compatibility
  DateTime get date => dateTime;

  Reminder({
    this.id,
    required this.title,
    required this.dateTime,
    this.notes,
    required this.type,
    required this.frequency,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'notes': notes,
      'type': type,
      'frequency': frequency,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      dateTime: DateTime.parse(map['dateTime']),
      notes: map['notes'],
      type: map['type'],
      frequency: map['frequency'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  Reminder copyWith({
    int? id,
    String? title,
    DateTime? dateTime,
    String? notes,
    String? type,
    String? frequency,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  DateTime getNextReminderDateTime() {
  DateTime nextDateTime = dateTime;
  final now = DateTime.now();
  
  // ✅ FIXED: Only skip if time has PASSED today
  while (nextDateTime.isBefore(now) || 
         (nextDateTime.day == now.day && 
          nextDateTime.month == now.month && 
          nextDateTime.year == now.year &&
          now.hour >= dateTime.hour &&
          now.minute >= dateTime.minute)) {
    switch (frequency) {
      case 'yearly':
        nextDateTime = DateTime(
          nextDateTime.year + 1,
          nextDateTime.month,
          nextDateTime.day,
          dateTime.hour,
          dateTime.minute,
        );
        break;
      case 'monthly':
        final daysInMonth = DateTime(nextDateTime.year, nextDateTime.month + 1, 0).day;
        nextDateTime = DateTime(
          nextDateTime.year,
          nextDateTime.month + 1,
          math.min(nextDateTime.day, daysInMonth),
          dateTime.hour,
          dateTime.minute,
        );
        break;
      case 'weekly':
        nextDateTime = nextDateTime.add(const Duration(days: 7));
        break;
      case 'daily':
        nextDateTime = nextDateTime.add(const Duration(days: 1));
        break;
    }
  }
  return nextDateTime;
}

  DateTime getExactReminderDateTime() => dateTime;
  
  DateTime getDailyReminderTime() {
    return DateTime(2000, 1, 1, dateTime.hour, dateTime.minute);
  }

  String getFormattedDateTime() {
    final now = DateTime.now();
    String dateStr;
    if (dateTime.year == now.year && 
        dateTime.month == now.month && 
        dateTime.day == now.day) {
      dateStr = 'Today';
    } else if (dateTime.year == now.year && 
               dateTime.month == now.month && 
               dateTime.day == now.day + 1) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}';
    }
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr • ${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  String toString() => 'Reminder(id: $id, title: $title, dateTime: $dateTime)';
}