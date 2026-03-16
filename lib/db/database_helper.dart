// database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_preference.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('preferences.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Only the User preferences table remains
    await db.execute('''
      CREATE TABLE user_preferences (
        pref_id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_language_code TEXT NOT NULL,
        target_language_code TEXT NOT NULL,
        font_size_scale REAL NOT NULL,
        overlay_opacity INTEGER NOT NULL,
        text_color_hex TEXT NOT NULL,
        bg_color_hex TEXT NOT NULL,
        is_tutorial_completed INTEGER NOT NULL
      )
    ''');
  }

  // Fetch preferences. If none exist, insert defaults and return them.
  Future<UserPreference> getPreferences() async {
    final db = await instance.database;
    final result = await db.query('user_preferences', limit: 1);

    if (result.isNotEmpty) {
      return UserPreference.fromMap(result.first);
    } else {
      // Create defaults
      final defaultPrefs = UserPreference(
        sourceLanguageCode: 'English',
        targetLanguageCode: 'None',
        fontSizeScale: 18.0,
        overlayOpacity: 80,
        textColorHex: '#FFFFFF',
        bgColorHex: '#000000',
        isTutorialCompleted: false,
      );
      await updatePreferences(defaultPrefs); // Saves defaults to DB
      return defaultPrefs;
    }
  }

  // Update preferences (Always overwrites the single row we use)
  Future<void> updatePreferences(UserPreference prefs) async {
    final db = await instance.database;

    // Check if a row exists
    final result = await db.query('user_preferences');

    if (result.isEmpty) {
      await db.insert('user_preferences', prefs.toMap());
    } else {
      await db.update(
        'user_preferences',
        prefs.toMap(),
        // Since we only ever have 1 row for local user settings, we just update the first row
        where: 'pref_id = ?',
        whereArgs: [result.first['pref_id']],
      );
    }
  }
}