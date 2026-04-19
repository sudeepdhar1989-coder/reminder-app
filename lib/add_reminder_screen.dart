import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'reminder_model.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final Function refreshReminders;

  const AddReminderScreen({
    Key? key,
    this.reminder,
    required this.refreshReminders,
  }) : super(key: key);

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  String _selectedType = 'birthday';
  String _selectedFrequency = 'yearly';

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  final List<String> _types = [
    'birthday',
    'anniversary',
    'event',
    'task',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _notesController.text = widget.reminder!.notes ?? '';
      _selectedDateTime = widget.reminder!.dateTime;
      _selectedType = widget.reminder!.type;
      _selectedFrequency = widget.reminder!.frequency;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ================= DATE & TIME =================

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedDateTime.hour,
        minute: _selectedDateTime.minute,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  // ================= SAVE =================

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    Reminder reminder;

    if (widget.reminder != null) {
      reminder = widget.reminder!.copyWith(
        title: _titleController.text,
        dateTime: _selectedDateTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        type: _selectedType,
        frequency: _selectedFrequency,
        isActive: true,
      );

      await _dbHelper.updateReminder(reminder);
      await _notificationService.cancelReminder(reminder.id!);
    } else {
      reminder = Reminder(
        title: _titleController.text,
        dateTime: _selectedDateTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        type: _selectedType,
        frequency: _selectedFrequency,
        createdAt: DateTime.now(),
      );

      final id = await _dbHelper.insertReminder(reminder);
      reminder.id = id;
    }

    await _notificationService.scheduleExactTimeReminder(reminder);

    widget.refreshReminders();

    if (mounted) Navigator.pop(context);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: Text(widget.reminder == null ? 'Add Reminder' : 'Edit Reminder'),
        backgroundColor: Colors.blue,
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCard(
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter title' : null,
                ),
              ),

              const SizedBox(height: 16),

              _buildCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(_formatDate(_selectedDateTime)),
                      onTap: _selectDate,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(_formatTime(_selectedDateTime)),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildCard(
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getTypeDisplayName(type)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
              ),

              const SizedBox(height: 16),

              _buildCard(
                child: DropdownButtonFormField<String>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: ['yearly', 'monthly', 'weekly', 'daily']
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(_getFrequencyDisplayName(f)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFrequency = v!),
                ),
              ),

              const SizedBox(height: 16),

              _buildCard(
                child: TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    widget.reminder == null ? 'Save Reminder' : 'Update Reminder',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: child,
    );
  }

  // ================= HELPERS =================

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'birthday':
        return '🎂 Birthday';
      case 'anniversary':
        return '❤️ Anniversary';
      case 'event':
        return '📅 Event';
      case 'task':
        return '📝 Task';
      default:
        return type;
    }
  }

  String _getFrequencyDisplayName(String frequency) {
    switch (frequency) {
      case 'yearly':
        return '📅 Yearly';
      case 'monthly':
        return '📆 Monthly';
      case 'weekly':
        return '📋 Weekly';
      case 'daily':
        return '⏰ Daily';
      default:
        return frequency;
    }
  }
}