import 'package:sqflite/sqflite.dart';
import 'package:kova/local_backend/database/database_service.dart';
import 'package:kova/shared/models/web_history.dart';

class BrowserHistoryRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<void> insert(WebHistory history) async {
    final db = await _dbService.database;
    await db.insert(
      'web_history',
      history.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WebHistory>> getHistory({int limit = 50}) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'web_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => WebHistory.fromMap(map)).toList();
  }

  Future<void> deleteOldHistory(DateTime before) async {
    final db = await _dbService.database;
    final seconds = (before.millisecondsSinceEpoch / 1000).round();
    await db.delete(
      'web_history',
      where: 'created_at < ?',
      whereArgs: [seconds],
    );
  }
}
