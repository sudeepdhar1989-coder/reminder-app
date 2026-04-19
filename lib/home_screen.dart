import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'database_helper.dart';
import 'notification_service.dart';
import 'reminder_model.dart';
import 'add_reminder_screen.dart';
import 'qr_share_screen.dart';
import 'qr_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  List<Reminder> _reminders = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

  String _selectedFilter = 'total';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _notificationService.init();
    await _loadReminders();
    setState(() => _isLoading = false);
  }

  Future<void> _loadReminders() async {
    final reminders = await _dbHelper.getAllReminders();
    setState(() => _reminders = reminders);
  }

  // ================= FILTER =================

  List<Reminder> _getFilteredReminders() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'active':
        return _reminders.where((r) => r.isActive).toList();
      case 'inactive':
        return _reminders.where((r) => !r.isActive).toList();
      case 'today':
        return _reminders.where((r) {
          final next = r.getNextReminderDateTime();
          return next.day == now.day &&
              next.month == now.month &&
              next.year == now.year;
        }).toList();
      case 'total':
      default:
        return _reminders;
    }
  }

  // ================= DASHBOARD =================

  Map<String, int> _calculateStats() {
    int total = _reminders.length;
    int active = _reminders.where((r) => r.isActive).length;
    int inactive = total - active;

    final now = DateTime.now();

    int today = _reminders.where((r) {
      final next = r.getNextReminderDateTime();
      return next.day == now.day &&
          next.month == now.month &&
          next.year == now.year;
    }).length;

    return {
      'total': total,
      'active': active,
      'inactive': inactive,
      'today': today,
    };
  }

  Widget _buildDashboard() {
    final stats = _calculateStats();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _statCard("Total", stats['total']!, Colors.blue, 'total'),
          _statCard("Active", stats['active']!, Colors.green, 'active'),
          _statCard("Paused", stats['inactive']!, Colors.orange, 'inactive'),
          _statCard("Today", stats['today']!, Colors.purple, 'today'),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value, Color color, String filterKey) {
    final isSelected = _selectedFilter == filterKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = filterKey),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0, end: value.toDouble()),
          builder: (context, animatedValue, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(isSelected ? 0.4 : 0.2),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: isSelected ? Border.all(color: color, width: 2) : null,
              ),
              child: Column(
                children: [
                  Text(
                    animatedValue.toInt().toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: TextStyle(color: color)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= BACKUP & RESTORE =================

  Future<void> _backupReminders() async {
    if (_reminders.isEmpty) {
      _showSnack('No reminders to backup.');
      return;
    }

    try {
      final backupData = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'reminders': _reminders.map((r) => r.toMap()).toList(),
      };

      final jsonString =
          const JsonEncoder.withIndent('  ').convert(backupData);

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final file = File('${dir.path}/reminders_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      // Works on both Android and iOS — opens native share sheet
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Reminders Backup – $timestamp',
      );
    } catch (e) {
      _showSnack('Backup failed: $e');
    }
  }

  Future<void> _restoreReminders() async {
    try {
      // ── Android-only storage permission ──
      if (Platform.isAndroid) {
        final manageStatus =
            await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            _showSnack('Storage permission required. Please grant in Settings.');
            await openAppSettings();
            return;
          }
        }
      }
      // iOS does NOT need storage permission for file picker

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowCompression: false,
      );

      if (result == null || result.files.isEmpty) return;

      // Read file — bytes work on both Android & iOS
      Uint8List? bytes = result.files.first.bytes;
      if (bytes == null) {
        final path = result.files.first.path;
        if (path == null) {
          _showSnack('Could not read file.');
          return;
        }
        bytes = await File(path).readAsBytes();
      }

      final jsonString = utf8.decode(bytes);
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      if (!backupData.containsKey('reminders') ||
          backupData['reminders'] is! List) {
        _showSnack('Invalid backup file.');
        return;
      }

      final List rawList = backupData['reminders'] as List;
      final int count = rawList.length;

      if (count == 0) {
        _showSnack('Backup file contains no reminders.');
        return;
      }

      final choice = await _showRestoreDialog(count);
      if (choice == null) return;

      if (choice == 'replace') {
        for (final r in _reminders) {
          await _notificationService.cancelReminder(r.id!);
        }
        await _dbHelper.deleteAllReminders();
      }

      int imported = 0;
      int failed = 0;
      for (final raw in rawList) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          map.remove('id');
          final reminder = Reminder.fromMap(map);
          final newId = await _dbHelper.insertReminder(reminder);
          if (reminder.isActive) {
            reminder.id = newId;
            await _notificationService.scheduleExactTimeReminder(reminder);
          }
          imported++;
        } catch (e) {
          failed++;
          debugPrint('Failed to import reminder: $e');
        }
      }

      await _loadReminders();

      if (failed > 0) {
        _showSnack('Restored $imported, skipped $failed invalid entries.');
      } else {
        _showSnack(
            'Restored $imported reminder${imported == 1 ? '' : 's'} successfully.');
      }
    } on FormatException {
      _showSnack('File is not valid JSON.');
    } catch (e) {
      _showSnack('Restore failed: $e');
    }
  }

  Future<String?> _showRestoreDialog(int count) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Backup'),
        content: Text(
          'Found $count reminder${count == 1 ? '' : 's'} in the backup.\n\n'
          '• Merge – keeps your existing reminders and adds the backup ones.\n'
          '• Replace – deletes all current reminders and loads the backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text('Merge'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= ACTIONS =================

  Future<void> _toggleActive(int id, bool isActive) async {
    final reminder = await _dbHelper.getReminder(id);
    if (reminder == null) return;

    reminder.isActive = isActive;
    await _dbHelper.updateReminder(reminder);

    if (isActive) {
      await _notificationService.scheduleExactTimeReminder(reminder);
    } else {
      await _notificationService.cancelReminder(id);
    }

    await _loadReminders();
  }

  // ================= NAVIGATION =================

  void _navigateToEdit(Reminder reminder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          reminder: reminder,
          refreshReminders: _loadReminders,
        ),
      ),
    );
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddReminderScreen(refreshReminders: _loadReminders),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final filteredReminders = _getFilteredReminders();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIds.length} selected'
              : 'My Reminders',
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white, // iOS needs explicit icon color

        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,

        actions: [
          // QR Scan
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      QRScanScreen(refreshReminders: _loadReminders),
                ),
              );
            },
          ),

          // QR Share
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              final selected = _reminders
                  .where((r) => _selectedIds.contains(r.id))
                  .toList();

              if (selected.isEmpty) {
                _showSnack('Select reminders first');
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRShareScreen(reminders: selected),
                ),
              );
            },
          ),

          // Backup / Restore menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'backup') _backupReminders();
              if (value == 'restore') _restoreReminders();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.backup, color: Colors.blue),
                  title: Text('Backup Reminders'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.restore, color: Colors.green),
                  title: Text('Restore Backup'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReminders,
              color: Colors.blue,
              child: _reminders.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("No reminders yet"),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _restoreReminders,
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore from Backup'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDashboard(),
                        Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            itemCount: filteredReminders.length,
                            itemBuilder: (context, index) {
                              final reminder = filteredReminders[index];
                              final nextDate =
                                  reminder.getNextReminderDateTime();
                              return _buildCard(reminder, nextDate);
                            },
                          ),
                        ),
                      ],
                    ),
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),
    );
  }

  // ================= CARD =================

  Widget _buildCard(Reminder reminder, DateTime nextDate) {
    final isSelected = _selectedIds.contains(reminder.id);

    return Dismissible(
      key: Key(reminder.id.toString()),
      direction: _isSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,

      confirmDismiss: (direction) async {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Reminder'),
            content: Text(
                'Are you sure you want to delete "${reminder.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return result ?? false;
      },

      onDismissed: (direction) async {
        final removed = reminder;

        setState(() {
          _reminders.removeWhere((r) => r.id == removed.id);
          _selectedIds.remove(removed.id);
        });

        await _notificationService.cancelReminder(removed.id!);
        await _dbHelper.deleteReminder(removed.id!);

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${removed.title} deleted'),
              duration: const Duration(seconds: 2),
            ),
          );
      },

      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),

      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  isSelected
                      ? Colors.blue.withOpacity(0.3)
                      : _getTypeColor(reminder.type).withOpacity(0.15),
                  Colors.white,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),

              leading: _isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(reminder.id!);
                          } else {
                            _selectedIds.remove(reminder.id);
                            if (_selectedIds.isEmpty) {
                              _isSelectionMode = false;
                            }
                          }
                        });
                      },
                    )
                  : CircleAvatar(
                      backgroundColor: _getTypeColor(reminder.type),
                      child: Icon(
                        _getTypeIcon(reminder.type),
                        color: Colors.white,
                      ),
                    ),

              title: Text(reminder.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChip(reminder.frequency),
                  Text('Next: ${_formatDate(nextDate)}'),
                ],
              ),

              trailing: _isSelectionMode
                  ? null
                  : Switch(
                      value: reminder.isActive,
                      onChanged: (v) => _toggleActive(reminder.id!, v),
                    ),

              onTap: () {
                if (_isSelectionMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(reminder.id);
                    } else {
                      _selectedIds.add(reminder.id!);
                    }
                    if (_selectedIds.isEmpty) _isSelectionMode = false;
                  });
                } else {
                  _navigateToEdit(reminder);
                }
              },

              onLongPress: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(reminder.id!);
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _buildChip(String frequency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_getFrequencyDisplayName(frequency)),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'birthday':   return Colors.pink;
      case 'anniversary': return Colors.red;
      case 'event':      return Colors.blue;
      case 'task':       return Colors.green;
      default:           return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'birthday':   return Icons.cake;
      case 'anniversary': return Icons.favorite;
      case 'event':      return Icons.event;
      case 'task':       return Icons.assignment;
      default:           return Icons.note;
    }
  }

  String _getFrequencyDisplayName(String frequency) {
    switch (frequency) {
      case 'yearly':  return 'Yearly';
      case 'monthly': return 'Monthly';
      case 'weekly':  return 'Weekly';
      case 'daily':   return 'Daily';
      default:        return frequency;
    }
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}