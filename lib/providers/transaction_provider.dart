import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/my_transaction.dart';

class TransactionProvider with ChangeNotifier {
  static const String _dbName = 'expenses.db';
  static const String _tableName = 'transactions';
  static const int _dbVersion = 2;

  Database? _database;
  Future<Database>? _opening;
  List<MyTransaction> _transactions = [];

  double _totalIncome = 0;
  double _totalExpense = 0;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _totalIncome - _totalExpense;

  List<MyTransaction> get transactions => [..._transactions];

  TransactionProvider() {
    fetchAndSetTransactions();
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) {
        print('Creating table $_tableName...');
        return db.execute(
          'CREATE TABLE $_tableName('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT, amount REAL, date TEXT, type TEXT, note TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading DB from $oldVersion to $newVersion');
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN note TEXT');
        }
      },
    );
  }

  // กระบวนการที่ 2
  Future<void> _initDatabase() async {
    if (_database != null) return;
    try {
      _database = await (_opening ??= _openDb());
      print('Database initialized');
    } catch (e) {
      print('Error initializing database: $e');
      _opening = null;
    }
  }

  // ---------- Create ----------
  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type, {
    String? note,
  }) async {
    await _initDatabase();
    if (_database == null) return;

    final newTransaction = MyTransaction(
      title: title,
      amount: amount,
      date: date,
      type: type,
      note: note,
    );

    final id = await _database!.insert(_tableName, newTransaction.toMap());
    print('Inserted transaction with id: $id');
    await fetchAndSetTransactions();
  }

  Future<void> fetchAndSetTransactions() async {
    await _initDatabase();
    if (_database == null) return;

    final dataList = await _database!.query(_tableName, orderBy: 'date DESC');
    _transactions = dataList
        .map((item) => MyTransaction.fromMap(item))
        .toList();
    await _loadSummary(); // อัปเดตยอดทุกครั้งที่โหลดข้อมูล
    print('Fetched ${_transactions.length} transactions.');
    notifyListeners();
  }

  Future<void> _loadSummary() async {
    final rows = await _database!.rawQuery(
      'SELECT type, SUM(amount) AS total FROM $_tableName GROUP BY type',
    );
    _totalIncome = 0;
    _totalExpense = 0;
    for (final row in rows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['type'] == TransactionType.income.name) {
        _totalIncome = total;
      } else if (row['type'] == TransactionType.expense.name) {
        _totalExpense = total;
      }
    }
  }

  double get balanceFromDart {
    double sum = 0;
    for (final tx in _transactions) {
      sum += tx.type == TransactionType.income ? tx.amount : -tx.amount;
    }
    return sum;
  }

  Future<void> updateTransaction(int id, MyTransaction newTransaction) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.update(
      _tableName,
      newTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _initDatabase();
    if (_database == null) return;
    await _database!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    await fetchAndSetTransactions();
  }

  // ---------- ข้อ 3: นำเข้า 100 รายการ ----------
  List<MyTransaction> _sampleData(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final isIncome = i % 4 == 0;
      return MyTransaction(
        title: isIncome
            ? 'รายรับตัวอย่าง #${i + 1}'
            : 'รายจ่ายตัวอย่าง #${i + 1}',
        amount: 50.0 + (i * 7) % 500,
        date: now.subtract(Duration(minutes: i)),
        type: isIncome ? TransactionType.income : TransactionType.expense,
        note: 'ข้อมูลตัวอย่าง',
      );
    });
  }

  // แบบที่ 1: ทีละรายการ
  Future<Duration> importSamplesOneByOne({int count = 100}) async {
    final sw = Stopwatch()..start();
    for (final tx in _sampleData(count)) {
      await addTransaction(
        tx.title,
        tx.amount,
        tx.date,
        tx.type,
        note: tx.note,
      );
    }
    sw.stop();
    return sw.elapsed;
  }

  // แบบที่ 2: batch ภายใน transaction
  Future<Duration> importSamplesWithBatch({int count = 100}) async {
    final sw = Stopwatch()..start();
    await _initDatabase();
    if (_database == null) return Duration.zero;
    await _database!.transaction((txn) async {
      final batch = txn.batch();
      for (final tx in _sampleData(count)) {
        batch.insert(_tableName, tx.toMap());
      }
      await batch.commit(noResult: true);
    });
    await fetchAndSetTransactions();
    sw.stop();
    return sw.elapsed;
  }
}
