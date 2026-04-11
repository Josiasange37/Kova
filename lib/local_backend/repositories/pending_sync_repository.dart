import 'package:sqflite/sqflite.dart';
import 'package:kova/local_backend/database/database_service.dart';
import 'package:kova/shared/models/pending_sync.dart';

class PendingSyncRepository {
  final DatabaseService _dbService = DatabaseService();

  Future<void> insert(PendingSync item) async {
    final db = await _dbService.database;
    await db.insert(
      'pending_sync',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingSync>> getAll() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'pending_sync',
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => PendingSync.fromMap(map)).toList();
  }

  Future<void> deleteList(List<String> ids) async {
    if (ids.isEmpty) return;
    
    final db = await _dbService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    
    await db.delete(
      'pending_sync',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
