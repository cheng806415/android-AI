import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/image_model.dart';

/// 本地存储服务 - 管理图片文件和历史记录数据库
class StorageService {
  static const String _dbName = 'image_history.db';
  static const String _tableName = 'generated_images';
  static const int _dbVersion = 1;

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
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            prompt TEXT NOT NULL,
            model TEXT NOT NULL,
            size TEXT NOT NULL,
            quality TEXT NOT NULL,
            group_name TEXT NOT NULL,
            localPath TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            generationTimeMs INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// 获取图片存储目录
  Future<String> get _imageDir async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/generated_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  /// 保存图片到本地并返回路径
  Future<String> saveImageLocally(Uint8List imageData,
      {String? extension}) async {
    final dir = await _imageDir;
    final ext = extension ?? 'png';
    final fileName = '${_uuid.v4()}.$ext';
    final filePath = '$dir/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(imageData);
    return filePath;
  }

  /// 保存生成记录到数据库
  Future<void> saveGenerationRecord(GeneratedImage image) async {
    final database = await db;
    await database.insert(
      _tableName,
      image.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有历史记录
  Future<List<GeneratedImage>> getAllRecords() async {
    final database = await db;
    final maps = await database.query(
      _tableName,
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => GeneratedImage.fromMap(m)).toList();
  }

  /// 获取分页记录
  Future<List<GeneratedImage>> getRecords(int page, int pageSize) async {
    final database = await db;
    final maps = await database.query(
      _tableName,
      orderBy: 'createdAt DESC',
      limit: pageSize,
      offset: page * pageSize,
    );
    return maps.map((m) => GeneratedImage.fromMap(m)).toList();
  }

  /// 删除单条记录及其本地图片
  Future<void> deleteRecord(String id) async {
    final database = await db;
    final records = await database.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (records.isNotEmpty) {
      final path = records.first['localPath'] as String;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await database.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有记录
  Future<void> clearAllRecords() async {
    final database = await db;
    final records = await database.query(_tableName);

    for (final record in records) {
      final path = record['localPath'] as String;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await database.delete(_tableName);
  }

  /// 获取记录总数
  Future<int> getRecordCount() async {
    final database = await db;
    final result =
        await database.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 搜索记录
  Future<List<GeneratedImage>> searchRecords(String keyword) async {
    final database = await db;
    final maps = await database.query(
      _tableName,
      where: 'prompt LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => GeneratedImage.fromMap(m)).toList();
  }

  /// 获取本地存储使用的空间大小（字节）
  Future<int> getStorageSize() async {
    final dir = await _imageDir;
    final directory = Directory(dir);
    if (!await directory.exists()) return 0;

    int totalSize = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }
}
