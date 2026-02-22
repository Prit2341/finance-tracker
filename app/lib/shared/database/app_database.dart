import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fintrack_v2.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        is_anomaly INTEGER DEFAULT 0,
        predicted_category TEXT,
        confidence REAL,
        anomaly_score REAL,
        was_corrected INTEGER DEFAULT 0,
        account_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE training_buffer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        correct_category TEXT NOT NULL,
        weight REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE model_metadata (
        id TEXT PRIMARY KEY,
        model_type TEXT NOT NULL,
        version INTEGER NOT NULL,
        accuracy REAL,
        created_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        total_balance REAL NOT NULL DEFAULT 0,
        usable_amount REAL NOT NULL DEFAULT 0,
        savings_amount REAL NOT NULL DEFAULT 0,
        minimum_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subscriptions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        billing_cycle TEXT NOT NULL,
        account_id TEXT,
        start_date TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL UNIQUE,
        budget_limit REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> clearAllData() async {
    final db = await database;
    final batch = db.batch();
    batch.delete('transactions');
    batch.delete('bank_accounts');
    batch.delete('subscriptions');
    batch.delete('budgets');
    batch.delete('training_buffer');
    batch.delete('model_metadata');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE bank_accounts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          bank_name TEXT NOT NULL,
          total_balance REAL NOT NULL DEFAULT 0,
          usable_amount REAL NOT NULL DEFAULT 0,
          savings_amount REAL NOT NULL DEFAULT 0,
          minimum_balance REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN account_id TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE subscriptions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          billing_cycle TEXT NOT NULL,
          account_id TEXT,
          start_date TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE budgets (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL UNIQUE,
          budget_limit REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
  }
}
