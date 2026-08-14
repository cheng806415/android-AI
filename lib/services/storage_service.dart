import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/generation_task.dart';
import '../models/image_model.dart';
import '../models/log_entry.dart';

/// 本地存储服务 - 管理图片文件、历史记录、任务和应用日志数据库
class StorageService {
  static const String _dbName = 'image_history.db';
  static const String _tableName = 'generated_images';
  static const String _taskTableName = 'generation_tasks';
  static const String _logTableName = 'app_logs';
  static const int _dbVersion = 6;
  static const _dcimChannel =
      MethodChannel('com.example.ai_image_generator/dcim');

  Database? _database;
  final _uuid = const Uuid();

  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_dbName';
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createImagesTable(db);
        await _createTasksTable(db);
        await _createLogsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(
              db, _tableName, '"group" TEXT NOT NULL DEFAULT ""', 'group');
          await _createLogsTable(db);
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(db, _tableName,
              'isFavorite INTEGER NOT NULL DEFAULT 0', 'isFavorite');
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(
              db, _tableName, 'count INTEGER NOT NULL DEFAULT 1', 'count');
          await _addColumnIfMissing(db, _tableName,
              'outputFormat TEXT NOT NULL DEFAULT "png"', 'outputFormat');
          await _addColumnIfMissing(
              db, _tableName, 'referenceImagePath TEXT', 'referenceImagePath');
          await _addColumnIfMissing(
              db,
              _tableName,
              'referenceImagePathsJson TEXT NOT NULL DEFAULT "[]"',
              'referenceImagePathsJson');
          await _addColumnIfMissing(
              db, _tableName, 'providerId TEXT', 'providerId');
          await _addColumnIfMissing(db, _tableName,
              'schemaVersion INTEGER NOT NULL DEFAULT 1', 'schemaVersion');
          await _addColumnIfMissing(
              db, _tableName, 'parentRecordId TEXT', 'parentRecordId');
        }
        if (oldVersion < 5) await _createTasksTable(db);
        if (oldVersion < 6) {
          await _addColumnIfMissing(
              db, _tableName, 'title TEXT NOT NULL DEFAULT ""', 'title');
          await _addColumnIfMissing(
              db, _tableName, 'category TEXT NOT NULL DEFAULT ""', 'category');
          await _addColumnIfMissing(db, _tableName,
              'tagsJson TEXT NOT NULL DEFAULT "[]"', 'tagsJson');
          await _addColumnIfMissing(
              db, _tableName, 'notes TEXT NOT NULL DEFAULT ""', 'notes');
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String definition, String name) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((column) => column['name'] == name)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  Future<void> _createImagesTable(Database db) => db.execute('''
    CREATE TABLE $_tableName (
      id TEXT PRIMARY KEY, prompt TEXT NOT NULL, model TEXT NOT NULL,
      size TEXT NOT NULL, quality TEXT NOT NULL, "group" TEXT NOT NULL DEFAULT "",
      localPath TEXT NOT NULL, createdAt TEXT NOT NULL, generationTimeMs INTEGER DEFAULT 0,
      isFavorite INTEGER NOT NULL DEFAULT 0, count INTEGER NOT NULL DEFAULT 1,
      outputFormat TEXT NOT NULL DEFAULT "png", referenceImagePath TEXT,
      referenceImagePathsJson TEXT NOT NULL DEFAULT "[]", providerId TEXT,
      schemaVersion INTEGER NOT NULL DEFAULT 1, parentRecordId TEXT,
      title TEXT NOT NULL DEFAULT "", category TEXT NOT NULL DEFAULT "",
      tagsJson TEXT NOT NULL DEFAULT "[]", notes TEXT NOT NULL DEFAULT ""
    )
  ''');

  Future<void> _createTasksTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS $_taskTableName (
      id TEXT PRIMARY KEY, configJson TEXT NOT NULL, status TEXT NOT NULL,
      attempt INTEGER NOT NULL DEFAULT 0, maxAttempts INTEGER NOT NULL DEFAULT 3,
      providerId TEXT, errorCode TEXT, errorMessage TEXT,
      resultPathsJson TEXT NOT NULL DEFAULT "[]", createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL, nextRetryAt TEXT
    )
  ''');

  Future<void> _createLogsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS $_logTableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT, level TEXT NOT NULL, tag TEXT NOT NULL,
      message TEXT NOT NULL, details TEXT, createdAt TEXT NOT NULL
    )
  ''');

  Future<String> get _imageDir async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/generated_images');
    if (!await imageDir.exists()) await imageDir.create(recursive: true);
    return imageDir.path;
  }

  Future<String> saveImageLocally(Uint8List imageData,
      {String? extension}) async {
    final path = '${await _imageDir}/${_uuid.v4()}.${extension ?? 'png'}';
    await File(path).writeAsBytes(imageData);
    return path;
  }

  Future<String> saveToDcim(String sourcePath, {String? fileName}) async {
    final name =
        fileName ?? 'ai_image_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      return await _dcimChannel.invokeMethod<String>('saveToDcim', {
            'sourcePath': sourcePath,
            'fileName': name,
          }) ??
          '';
    } on PlatformException catch (e) {
      throw Exception('保存到相册失败: ${e.message}');
    }
  }

  Future<void> saveGenerationRecord(GeneratedImage image) async =>
      (await db).insert(_tableName, image.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveTask(GenerationTask task) async =>
      (await db).insert(_taskTableName, task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<GenerationTask>> getTasks() async {
    final maps =
        await (await db).query(_taskTableName, orderBy: 'createdAt ASC');
    return maps.map(GenerationTask.fromMap).toList();
  }

  Future<void> deleteTask(String id) async =>
      (await db).delete(_taskTableName, where: 'id = ?', whereArgs: [id]);

  Future<void> clearFinishedTasks() async => (await db).delete(
        _taskTableName,
        where: 'status IN (?, ?, ?)',
        whereArgs: ['succeeded', 'failed', 'cancelled'],
      );

  Future<void> insertLog(LogEntry entry) async {
    try {
      await (await db).insert(_logTableName, entry.toMap());
    } catch (_) {}
  }

  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    final maps = await (await db)
        .query(_logTableName, orderBy: 'createdAt DESC', limit: limit);
    return maps.map(LogEntry.fromMap).toList();
  }

  Future<void> clearLogs() async => (await db).delete(_logTableName);

  Future<void> updateMetadata({
    required String id,
    required String title,
    required String category,
    required List<String> tags,
    required String notes,
  }) async {
    await (await db).update(
      _tableName,
      {
        'title': title.trim(),
        'category': category.trim(),
        'tagsJson': jsonEncode(
          tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
        ),
        'notes': notes.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> exportBackupJson() async {
    final records = await getAllRecords();
    final exported = <Map<String, dynamic>>[];
    for (final record in records) {
      final map = record.toMap();
      map['localPath'] =
          record.localPath.isNotEmpty && await File(record.localPath).exists()
              ? record.localPath
              : '';
      final referencePaths = <String>[];
      for (final path in record.referenceImagePaths) {
        if (await File(path).exists()) referencePaths.add(path);
      }
      map['referenceImagePathsJson'] = jsonEncode(referencePaths);
      if (record.referenceImagePath == null ||
          !await File(record.referenceImagePath!).exists()) {
        map['referenceImagePath'] = null;
      }
      exported.add(map);
    }
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': exported,
    });
  }

  Future<int> importBackupJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['records'] is! List) {
      throw const FormatException('备份文件格式无效');
    }
    final database = await db;
    var imported = 0;
    await database.transaction((transaction) async {
      for (final value in decoded['records'] as List) {
        if (value is! Map) continue;
        final record = GeneratedImage.fromMap(Map<String, dynamic>.from(value));
        await transaction.insert(
          _tableName,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        imported++;
      }
    });
    return imported;
  }

  Future<List<String>> getCategories() async {
    final records = await getAllRecords();
    return records
        .map((record) => record.category)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<String>> getTags() async {
    final records = await getAllRecords();
    return records
        .expand((record) => record.tags)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<GeneratedImage>> filterRecords(
      {String? category, String? tag}) async {
    final records = await getAllRecords();
    return records.where((record) {
      final categoryMatches =
          category == null || category.isEmpty || record.category == category;
      final tagMatches =
          tag == null || tag.isEmpty || record.tags.contains(tag);
      return categoryMatches && tagMatches;
    }).toList();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async =>
      (await db).update(_tableName, {'isFavorite': isFavorite ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);

  Future<List<GeneratedImage>> getFavoriteRecords() async =>
      _readImages(where: 'isFavorite = 1', orderBy: 'createdAt DESC');
  Future<List<GeneratedImage>> getAllRecords() async =>
      _readImages(orderBy: 'createdAt DESC');
  Future<List<GeneratedImage>> getRecords(int page, int pageSize) async =>
      _readImages(
          orderBy: 'createdAt DESC', limit: pageSize, offset: page * pageSize);
  Future<List<GeneratedImage>> searchRecords(String keyword) async =>
      _readImages(
          where: 'prompt LIKE ?',
          whereArgs: ['%$keyword%'],
          orderBy: 'createdAt DESC');

  Future<List<GeneratedImage>> _readImages(
      {String? where,
      List<Object?>? whereArgs,
      String? orderBy,
      int? limit,
      int? offset}) async {
    final maps = await (await db).query(_tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset);
    return maps.map(GeneratedImage.fromMap).toList();
  }

  Future<void> deleteRecord(String id) async {
    final database = await db;
    final records =
        await database.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (records.isNotEmpty) {
      final file = File(records.first['localPath'] as String);
      if (await file.exists()) await file.delete();
    }
    await database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllRecords() async {
    final database = await db;
    final records = await database.query(_tableName);
    for (final record in records) {
      final file = File(record['localPath'] as String);
      if (await file.exists()) await file.delete();
    }
    await database.delete(_tableName);
  }

  Future<int> getRecordCount() async =>
      Sqflite.firstIntValue(await (await db)
          .rawQuery('SELECT COUNT(*) as count FROM $_tableName')) ??
      0;

  Future<int> getStorageSize() async {
    final directory = Directory(await _imageDir);
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
