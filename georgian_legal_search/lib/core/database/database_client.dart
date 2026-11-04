import 'dart:io';
import 'dart:typed_data';
import 'dart:ffi';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_pkg;

class DatabaseClient {
  Database? _civilDb;
  Database? _adminDb;

  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final civilDbPath = r'C:\Coding Projects\PROTOTYPE XKIL\civil_decisions.db';
    final adminDbPath = r'C:\Coding Projects\PROTOTYPE XKIL\admin_decisions.db';

    _civilDb = await databaseFactory.openDatabase(civilDbPath);
    _adminDb = await databaseFactory.openDatabase(adminDbPath);

    // Load sqlite-vec extension for vector search
    try {
      final extPath = r'C:\Coding Projects\PROTOTYPE XKIL\venv\Lib\site-packages\sqlite_vec\vec0.dll';
      if (File(extPath).existsSync()) {
        final sqlite3 = sqlite3_pkg.sqlite3;
        sqlite3.ensureExtensionLoaded(sqlite3_pkg.SqliteExtension.inLibrary(
          DynamicLibrary.open(extPath),
          'sqlite3_vec_init'
        ));
        print('[DatabaseClient] sqlite-vec extension loaded successfully');
      }
    } catch (e) {
      print('[DatabaseClient] Error loading sqlite-vec: $e');
    }
  }

  Database? _getDb(String category) {
    if (category == 'Civil') return _civilDb;
    if (category == 'Administrative') return _adminDb;
    return null;
  }

  Future<List<Map<String, dynamic>>> rawFtsSearch(String queryText, String category, {int limit = 50}) async {
    final db = _getDb(category);
    if (db == null) return [];
    
    final tokens = queryText.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final ftsQuery = tokens.map((t) => '"${t.replaceAll('"', '""')}*"').join(' OR ');
    
    final results = await db.rawQuery('''
      SELECT 
        d.case_number as id, 
        d.case_number, 
        d.date, 
        d.result, 
        f.full_text as chunk_text, 
        bm25(decisions_fts) as rank 
      FROM decisions_fts f
      JOIN decisions d ON d.case_number = f.case_number
      WHERE decisions_fts MATCH ?
      ORDER BY rank 
      LIMIT ?
    ''', [ftsQuery, limit]);
    
    return results;
  }

  Future<List<Map<String, dynamic>>> rawVectorSearch(List<double> queryVector, String category, {int limit = 50}) async {
    final db = _getDb(category);
    if (db == null) return [];
    
    final float32List = Float32List.fromList(queryVector);
    final uint8List = float32List.buffer.asUint8List();

    try {
      final results = await db.rawQuery('''
        SELECT 
          c.case_number as id, 
          c.chunk_id, 
          c.chunk_text, 
          d.case_number,
          d.date,
          d.result,
          vec_distance_cosine(v.embedding, ?) as distance
        FROM vec_chunks v
        JOIN chunks c ON c.chunk_rowid = v.chunk_rowid
        JOIN decisions d ON d.case_number = c.case_number
        WHERE vec_distance_cosine(v.embedding, ?) < 0.7
        ORDER BY distance ASC
        LIMIT ?
      ''', [uint8List, uint8List, limit]);
      return results;
    } catch (e) {
      print('[DatabaseClient] Vector search failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFullDecisionText(String caseNumber, String category) async {
    final db = _getDb(category);
    if (db == null) return null;
    
    final results = await db.query(
      'decisions',
      where: 'case_number = ?',
      whereArgs: [caseNumber],
      limit: 1,
    );
    if (results.isNotEmpty) {
      final map = Map<String, dynamic>.from(results.first);
      map['id'] = map['case_number']; // ensure id exists for models
      return map;
    }
    return null;
  }
}
