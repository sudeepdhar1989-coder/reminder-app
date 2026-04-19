import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'reminder_model.dart';

class DatabaseHelper {
  // ✅ Singleton
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // ✅ DB Getter
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ✅ Initialize DB
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'reminders.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ✅ Create Table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        notes TEXT,
        type TEXT NOT NULL,
        frequency TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  // ✅ SAFE MIGRATION (no crash risk)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE reminders_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          dateTime TEXT NOT NULL,
          notes TEXT,
          type TEXT NOT NULL,
          frequency TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        INSERT INTO reminders_new (id, title, dateTime, notes, type, frequency, isActive, createdAt)
        SELECT id, title, date, notes, type, frequency, isActive, createdAt FROM reminders
      ''');

      await db.execute('DROP TABLE reminders');
      await db.execute('ALTER TABLE reminders_new RENAME TO reminders');
    }
  }

  // ✅ INSERT
  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    print('💾 Inserting: ${reminder.title}');
    return await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ✅ GET ALL (sorted)
  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      orderBy: 'dateTime ASC',
    );

    print('🔍 Found ${maps.length} reminders');

    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  // ✅ GET ACTIVE
  Future<List<Reminder>> getActiveReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'dateTime ASC',
    );

    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  // ✅ GET SINGLE
  Future<Reminder?> getReminder(int id) async {
    final db = await database;
    final maps =
        await db.query('reminders', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Reminder.fromMap(maps.first);
    }
    return null;
  }

  // ✅ UPDATE
  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    print('✏️ Updating: ${reminder.title}');
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  // ✅ DELETE ONE
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ DELETE ALL (used for backup restore → replace)
  Future<void> deleteAllReminders() async {
    final db = await database;
    await db.delete('reminders');
    await db.execute("DELETE FROM sqlite_sequence WHERE name='reminders'");
    print('🗑️ All reminders deleted & ID reset');
  }

  // ✅ CLEAR TABLE (best for debug)
  Future<void> clearDatabase() async {
    final db = await database;

    final count = await db.delete('reminders');

    // 🔥 Reset auto-increment
    await db.execute("DELETE FROM sqlite_sequence WHERE name='reminders'");

    print('🧹 Cleared $count reminders & reset ID');
  }

  // ✅ FULL DELETE (like uninstall)
  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reminders.db');

    await deleteDatabase(path);
    _database = null;

    print('🔥 Database completely deleted');
  }

  // ✅ CLOSE DB (optional)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}