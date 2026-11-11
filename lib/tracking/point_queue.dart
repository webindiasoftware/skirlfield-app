import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class QueuedPoint {
  QueuedPoint(this.id, this.sessionId, this.payload);
  final int id;
  final int sessionId;
  final Map<String, dynamic> payload;
}

/// Offline store for GPS points. Points survive no network, app restarts and phone reboots,
/// and are deleted only after the server confirms the batch.
class PointQueue {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'skirlfield_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE points (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL, payload TEXT NOT NULL)');
        await db.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
      },
    );
    return _db!;
  }

  static Future<void> add(int sessionId, Map<String, dynamic> payload) async {
    final db = await _open();
    await db.insert('points', {'session_id': sessionId, 'payload': jsonEncode(payload)});
  }

  /// Oldest points of the oldest session still waiting (batches never mix sessions).
  static Future<List<QueuedPoint>> oldest({int limit = 300}) async {
    final db = await _open();
    final first = await db.query('points', columns: ['session_id'], orderBy: 'id', limit: 1);
    if (first.isEmpty) return [];
    final sid = first.first['session_id'] as int;
    final rows = await db.query('points', where: 'session_id = ?', whereArgs: [sid], orderBy: 'id', limit: limit);
    return rows
        .map((r) => QueuedPoint(r['id'] as int, r['session_id'] as int, Map<String, dynamic>.from(jsonDecode(r['payload'] as String) as Map)))
        .toList();
  }

  static Future<void> remove(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _open();
    await db.delete('points', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
  }

  static Future<int> count() async {
    final db = await _open();
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM points')) ?? 0;
  }

  static Future<int> nextSeq() async {
    final n = int.tryParse(await getMeta('seq') ?? '') ?? 0;
    await setMeta('seq', '${n + 1}');
    return n + 1;
  }

  static Future<String?> getMeta(String k) async {
    final db = await _open();
    final r = await db.query('meta', where: 'k = ?', whereArgs: [k], limit: 1);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  static Future<void> setMeta(String k, String? v) async {
    final db = await _open();
    if (v == null) {
      await db.delete('meta', where: 'k = ?', whereArgs: [k]);
    } else {
      await db.insert('meta', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
