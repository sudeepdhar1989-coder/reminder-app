import 'package:flutter/material.dart';
import 'reminder_model.dart';

class MultiSelectBottomSheet extends StatefulWidget {
  final List<Reminder> reminders;
  final Function(List<Reminder>) onShareSelected;

  const MultiSelectBottomSheet({
    Key? key,
    required this.reminders,
    required this.onShareSelected,
  }) : super(key: key);

  @override
  State<MultiSelectBottomSheet> createState() => _MultiSelectBottomSheetState();
}

class _MultiSelectBottomSheetState extends State<MultiSelectBottomSheet> {
  late Set<int> _selectedIds;
  int _selectedCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
  }

  @override
  Widget build(BuildContext context) {
    _selectedCount = _selectedIds.length;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.share, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Share Reminders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_selectedCount selected',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.reminders.length,
                itemBuilder: (context, index) {
                  final reminder = widget.reminders[index];
                  final isSelected = _selectedIds.contains(reminder.id);
                  
                  return CheckboxListTile(
                    title: Text(
                      reminder.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('${reminder.type} • ${reminder.frequency}'),
                    secondary: CircleAvatar(
                      backgroundColor: _getTypeColor(reminder.type),
                      child: Icon(_getTypeIcon(reminder.type), size: 18),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(reminder.id!);
                        } else {
                          _selectedIds.remove(reminder.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedCount > 0
                      ? () {
                          final selected = widget.reminders
                              .where((r) => _selectedIds.contains(r.id))
                              .toList();
                          widget.onShareSelected(selected);
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Share ($_selectedCount)'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'birthday': return Colors.pink;
      case 'anniversary': return Colors.red;
      case 'event': return Colors.blue;
      case 'task': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'birthday': return Icons.cake;
      case 'anniversary': return Icons.favorite;
      case 'event': return Icons.event;
      case 'task': return Icons.assignment;
      default: return Icons.note;
    }
  }
}