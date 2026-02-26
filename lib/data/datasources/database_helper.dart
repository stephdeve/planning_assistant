// ============================================================
// DATABASE HELPER — COUCHE DATA / DATASOURCE
// Gère la création, migration et accès à la base SQLite.
// Pattern Singleton pour éviter plusieurs connexions simultanées.
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton gérant la connexion à la base SQLite locale.
/// Utilise le pattern "lazy initialization" pour n'ouvrir la base
/// qu'au premier accès.
class DatabaseHelper {
  // ─── Singleton pattern ───────────────────────────────────
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Nom et version de la base (incrémenter la version déclenche onUpgrade)
  static const String _dbName = 'vocal_planning.db';
  static const int _dbVersion = 1;

  // ─── Noms de la table et des colonnes ───────────────────
  static const String tableTask = 'tasks';
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colScheduledDateTime = 'scheduled_date_time';
  static const String colRecurrenceType = 'recurrence_type';
  static const String colRecurrenceIntervalHours = 'recurrence_interval_hours';
  static const String colIsCompleted = 'is_completed';
  static const String colIsActive = 'is_active';
  static const String colCreatedAt = 'created_at';
  static const String colNextOccurrence = 'next_occurrence';

  // ─── Accès à la base (crée si nécessaire) ───────────────
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crée le schéma initial de la base de données
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTask (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colTitle TEXT NOT NULL,
        $colDescription TEXT NOT NULL,
        $colScheduledDateTime INTEGER NOT NULL,
        $colRecurrenceType INTEGER NOT NULL DEFAULT 0,
        $colRecurrenceIntervalHours INTEGER NOT NULL DEFAULT 1,
        $colIsCompleted INTEGER NOT NULL DEFAULT 0,
        $colIsActive INTEGER NOT NULL DEFAULT 1,
        $colCreatedAt INTEGER NOT NULL,
        $colNextOccurrence INTEGER
      )
    ''');

    // Index pour accélérer les requêtes sur les dates (très fréquentes)
    await db.execute('''
      CREATE INDEX idx_scheduled_date 
      ON $tableTask ($colScheduledDateTime)
    ''');

    // Index pour filtrer rapidement les tâches actives
    await db.execute('''
      CREATE INDEX idx_is_active 
      ON $tableTask ($colIsActive, $colIsCompleted)
    ''');
  }

  /// Migration de schéma en cas de mise à jour de version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Pour l'instant pas de migration nécessaire (v1 → v1)
    // Exemple futur : if (oldVersion < 2) { await db.execute(...); }
  }

  // ─── Opérations CRUD génériques ─────────────────────────

  Future<int> insert(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableTask, row);
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    final db = await database;
    return await db.query(tableTask, orderBy: '$colScheduledDateTime ASC');
  }

  Future<Map<String, dynamic>?> queryById(int id) async {
    final db = await database;
    final results = await db.query(
      tableTask,
      where: '$colId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<List<Map<String, dynamic>>> queryByDateRange(
    int startMs,
    int endMs,
  ) async {
    final db = await database;
    return await db.query(
      tableTask,
      where: '$colScheduledDateTime BETWEEN ? AND ?',
      whereArgs: [startMs, endMs],
      orderBy: '$colScheduledDateTime ASC',
    );
  }

  Future<int> update(Map<String, dynamic> row, int id) async {
    final db = await database;
    return await db.update(
      tableTask,
      row,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      tableTask,
      where: '$colId = ?',
      whereArgs: [id],
    );
  }

  /// Ferme la connexion (utile pour les tests)
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
