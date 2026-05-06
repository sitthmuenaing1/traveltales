// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  static const String _settingsTable = 'app_settings';
  static const String _passcodeKey = 'passcode';
  static const String defaultPasscode = '012345';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('traveltales.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Messages table
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Posts table
    await db.execute('''
      CREATE TABLE posts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        image TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_settingsTable(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert(
      _settingsTable,
      {'key': _passcodeKey, 'value': defaultPasscode},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS posts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          image TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_settingsTable(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      await db.insert(
        _settingsTable,
        {'key': _passcodeKey, 'value': defaultPasscode},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ─────────────────────────────────────────
  // SETTINGS (key/value)
  // ─────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      _settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      _settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getPasscode() async {
    final value = await getSetting(_passcodeKey);
    if (value != null && value.isNotEmpty) return value;
    await setSetting(_passcodeKey, defaultPasscode);
    return defaultPasscode;
  }

  // ─────────────────────────────────────────
  // MESSAGES CRUD
  // ─────────────────────────────────────────

  Future<int> insertMessage(String title, String content) async {
    final db = await instance.database;
    return await db.insert('messages', {
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllMessages() async {
    final db = await instance.database;
    return await db.query('messages', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getMessage(int id) async {
    final db = await instance.database;
    final result = await db.query('messages', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateMessage(int id, String title, String content) async {
    final db = await instance.database;
    return await db.update(
      'messages',
      {'title': title, 'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMessage(int id) async {
    final db = await instance.database;
    return await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────
  // POSTS CRUD
  // ─────────────────────────────────────────

  // INSERT post
  Future<int> insertPost(Post post) async {
    final db = await instance.database;
    return await db.insert('posts', {
      'title': post.title,
      'content': post.content,
      'image': post.image,
      'createdAt': DateTime.now().toString(),
    });
  }

  // READ ALL posts
  Future<List<Post>> getAllPosts() async {
    final db = await instance.database;
    final maps = await db.query('posts', orderBy: 'id DESC');
    return maps.map((map) => Post.fromMap(map)).toList();
  }

  // READ ONE post
  Future<Post?> getPost(int id) async {
    final db = await instance.database;
    final result = await db.query('posts', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Post.fromMap(result.first) : null;
  }

  // UPDATE post
  Future<int> updatePost(Post post) async {
    final db = await instance.database;
    return await db.update(
      'posts',
      {
        'title': post.title,
        'content': post.content,
        'image': post.image,
      },
      where: 'id = ?',
      whereArgs: [post.id],
    );
  }

  // DELETE post
  Future<int> deletePost(int id) async {
    final db = await instance.database;
    return await db.delete('posts', where: 'id = ?', whereArgs: [id]);
  }

  // DELETE MANY posts (bulk)
  Future<int> deletePosts(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await instance.database;

    final batch = db.batch();
    for (final id in ids) {
      batch.delete('posts', where: 'id = ?', whereArgs: [id]);
    }

    final results = await batch.commit(noResult: false);
    return results.whereType<int>().fold<int>(0, (sum, value) => sum + value);
  }

  // CLOSE DATABASE
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}