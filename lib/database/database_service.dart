import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../annual_expenses/annual_expense.dart';
import '../categories/expense_category.dart';
import '../planned_expenses/planned_expense.dart';
import '../recurring_expenses/recurring_expense.dart';
import '../transaction/final_transaction.dart';

class DatabaseService {
  DatabaseService._privateConstructor();

  static final DatabaseService instance =
      DatabaseService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'personal_finance.db');

    return openDatabase(
      path,
      version: 9,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await _createTransactionsTable(db);
    await _createMonthlyBudgetsTable(db);
    await _createYearlyBudgetsTable(db);
    await _createAnnualExpensesTableV5(db);
    await _createPlannedExpensesTableV7(db);
    await _createRecurringExpensesTableV7(db);
    await _createCategoriesTableV8(db);
    await _seedDefaultCategoriesV8(db);
    await _createAppSettingsTableV9(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createMonthlyBudgetsTable(db);
    }

    if (oldVersion < 3) {
      await _createYearlyBudgetsTable(db);
    }

    if (oldVersion < 4) {
      await _createAnnualExpensesTableV4(db);
      await _migrateYearlyBudgetsIntoAnnualExpensesV4(db);
    }

    if (oldVersion < 5) {
      await _migrateAnnualExpensesToV5(db);
    }

    if (oldVersion < 6) {
      await _createPlannedExpensesTableV6(db);
      await _migrateFixedExpensesToPlannedExpensesV6(db);
    }

    if (oldVersion < 7) {
      await _upgradePlannedExpensesToV7(db);
      await _createRecurringExpensesTableV7(db);
    }

    if (oldVersion < 8) {
      await _createCategoriesTableV8(db);
      await _seedDefaultCategoriesV8(db);
    }

    if (oldVersion < 9) {
      await _createAppSettingsTableV9(db);
    }
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        is_income INTEGER NOT NULL,
        date TEXT NOT NULL
      )
      ''',
    );
  }

  Future<void> _createMonthlyBudgetsTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS monthly_budgets (
        month_key TEXT PRIMARY KEY,
        fixed_expenses REAL NOT NULL DEFAULT 0,
        savings_goal REAL NOT NULL DEFAULT 0
      )
      ''',
    );
  }

  Future<void> _createYearlyBudgetsTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS yearly_budgets (
        year_key INTEGER PRIMARY KEY,
        annual_fixed_expenses REAL NOT NULL DEFAULT 0
      )
      ''',
    );
  }

  Future<void> _createAnnualExpensesTableV4(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS annual_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_key INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL
      )
      ''',
    );
  }

  Future<void> _createAnnualExpensesTableV5(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS annual_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_key INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'Altro',
        due_date TEXT NOT NULL,
        saving_start_date TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        paid_transaction_id INTEGER
      )
      ''',
    );
  }

  Future<void> _createPlannedExpensesTableV6(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS planned_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'Altro',
        due_date TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        paid_transaction_id INTEGER
      )
      ''',
    );
  }

  Future<void> _createPlannedExpensesTableV7(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS planned_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'Altro',
        due_date TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        paid_transaction_id INTEGER,
        recurring_expense_id INTEGER
      )
      ''',
    );
  }

  Future<void> _upgradePlannedExpensesToV7(Database db) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(planned_expenses)',
    );

    final hasRecurringColumn = columns.any(
      (column) => column['name'] == 'recurring_expense_id',
    );

    if (!hasRecurringColumn) {
      await db.execute(
        'ALTER TABLE planned_expenses ADD COLUMN recurring_expense_id INTEGER',
      );
    }
  }

  Future<void> _createRecurringExpensesTableV7(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL DEFAULT 'Altro',
        day_of_month INTEGER NOT NULL,
        start_month TEXT NOT NULL,
        end_month TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
      ''',
    );
  }

  Future<void> _createCategoriesTableV8(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        icon_key TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_protected INTEGER NOT NULL DEFAULT 0
      )
      ''',
    );
  }


  Future<void> _createAppSettingsTableV9(Database db) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
      ''',
    );
  }

  Future<void> _seedDefaultCategoriesV8(Database db) async {
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM categories',
    );

    final count = (countResult.first['total'] as num).toInt();

    if (count > 0) return;

    final defaults = <Map<String, dynamic>>[
      {
        'name': 'Spesa',
        'icon_key': 'shopping_cart',
        'color_value': 0xFF5470D8,
        'is_active': 1,
        'sort_order': 0,
        'is_protected': 0,
      },
      {
        'name': 'Casa',
        'icon_key': 'home',
        'color_value': 0xFF6E9C76,
        'is_active': 1,
        'sort_order': 1,
        'is_protected': 0,
      },
      {
        'name': 'Trasporti',
        'icon_key': 'car',
        'color_value': 0xFFD78A55,
        'is_active': 1,
        'sort_order': 2,
        'is_protected': 0,
      },
      {
        'name': 'Svago',
        'icon_key': 'movie',
        'color_value': 0xFF9B72CF,
        'is_active': 1,
        'sort_order': 3,
        'is_protected': 0,
      },
      {
        'name': 'Ristorante',
        'icon_key': 'restaurant',
        'color_value': 0xFFD86666,
        'is_active': 1,
        'sort_order': 4,
        'is_protected': 0,
      },
      {
        'name': 'Studio',
        'icon_key': 'school',
        'color_value': 0xFF58A6A6,
        'is_active': 1,
        'sort_order': 5,
        'is_protected': 0,
      },
      {
        'name': 'Altro',
        'icon_key': 'receipt',
        'color_value': 0xFF8B8F9C,
        'is_active': 1,
        'sort_order': 999,
        'is_protected': 1,
      },
    ];

    final batch = db.batch();

    for (final category in defaults) {
      batch.insert(
        'categories',
        category,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> _migrateYearlyBudgetsIntoAnnualExpensesV4(
    Database db,
  ) async {
    final oldBudgets = await db.query('yearly_budgets');

    for (final row in oldBudgets) {
      final int year = row['year_key'] as int;
      final double amount =
          (row['annual_fixed_expenses'] as num).toDouble();

      if (amount <= 0) continue;

      await db.insert(
        'annual_expenses',
        {
          'year_key': year,
          'name': 'Spese annuali precedenti',
          'amount': amount,
        },
      );
    }
  }

  Future<void> _migrateAnnualExpensesToV5(Database db) async {
    final oldExpenses = await db.query('annual_expenses');

    await db.execute(
      'ALTER TABLE annual_expenses RENAME TO annual_expenses_v4_backup',
    );

    await _createAnnualExpensesTableV5(db);

    for (final row in oldExpenses) {
      final year = row['year_key'] as int;

      await db.insert(
        'annual_expenses',
        {
          'id': row['id'],
          'year_key': year,
          'name': row['name'],
          'amount': row['amount'],
          'category': 'Altro',
          'due_date': DateTime(year, 12, 31, 12).toIso8601String(),
          'saving_start_date': DateTime(year, 1, 1, 12).toIso8601String(),
          'is_paid': 0,
          'paid_transaction_id': null,
        },
      );
    }

    await db.execute(
      'DROP TABLE annual_expenses_v4_backup',
    );
  }

  Future<void> _migrateFixedExpensesToPlannedExpensesV6(
    Database db,
  ) async {
    final oldBudgets = await db.query(
      'monthly_budgets',
      where: 'fixed_expenses > 0',
    );

    for (final row in oldBudgets) {
      final monthKey = row['month_key'] as String;
      final parts = monthKey.split('-');

      if (parts.length != 2) continue;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);

      if (year == null || month == null || month < 1 || month > 12) {
        continue;
      }

      final amount = (row['fixed_expenses'] as num).toDouble();
      if (amount <= 0) continue;

      final dueDate = DateTime(
        year,
        month + 1,
        0,
        12,
      );

      await db.insert(
        'planned_expenses',
        {
          'name': 'Spese previste precedenti',
          'amount': amount,
          'category': 'Altro',
          'due_date': dueDate.toIso8601String(),
          'is_paid': 0,
          'paid_transaction_id': null,
        },
      );

      await db.update(
        'monthly_budgets',
        {'fixed_expenses': 0.0},
        where: 'month_key = ?',
        whereArgs: [monthKey],
      );
    }
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  // =====================================================
  // TRANSAZIONI
  // =====================================================

  Future<int> insertTransaction(
    FinanceTransaction transaction,
  ) async {
    final db = await database;

    return db.insert(
      'transactions',
      transaction.toMap(),
    );
  }

  Future<List<FinanceTransaction>> getTransactions() async {
    final db = await database;

    final maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );

    return maps.map(FinanceTransaction.fromMap).toList();
  }

  Future<List<FinanceTransaction>> getTransactionsForMonth(
    DateTime month,
  ) async {
    final db = await database;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    return maps.map(FinanceTransaction.fromMap).toList();
  }

  Future<List<FinanceTransaction>> getTransactionsForYear(
    int year,
  ) async {
    final db = await database;

    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    return maps.map(FinanceTransaction.fromMap).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      await txn.update(
        'annual_expenses',
        {
          'is_paid': 0,
          'paid_transaction_id': null,
        },
        where: 'paid_transaction_id = ?',
        whereArgs: [id],
      );

      await txn.update(
        'planned_expenses',
        {
          'is_paid': 0,
          'paid_transaction_id': null,
        },
        where: 'paid_transaction_id = ?',
        whereArgs: [id],
      );

      return txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> updateTransaction(
    FinanceTransaction transaction,
  ) async {
    final db = await database;

    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // =====================================================
  // PIANIFICAZIONE MENSILE / RISPARMIO
  // =====================================================

  Future<void> saveMonthlyBudget(
    DateTime month, {
    required double fixedExpenses,
    required double savingsGoal,
  }) async {
    final db = await database;

    await db.insert(
      'monthly_budgets',
      {
        'month_key': _monthKey(month),
        'fixed_expenses': fixedExpenses,
        'savings_goal': savingsGoal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, double>> getMonthlyBudget(
    DateTime month,
  ) async {
    final db = await database;

    final result = await db.query(
      'monthly_budgets',
      where: 'month_key = ?',
      whereArgs: [_monthKey(month)],
      limit: 1,
    );

    if (result.isEmpty) {
      return {
        'fixedExpenses': 0.0,
        'savingsGoal': 0.0,
      };
    }

    final row = result.first;

    return {
      'fixedExpenses': (row['fixed_expenses'] as num).toDouble(),
      'savingsGoal': (row['savings_goal'] as num).toDouble(),
    };
  }

  // =====================================================
  // SPESE PREVISTE DEL MESE
  // =====================================================

  Future<int> insertPlannedExpense(
    PlannedExpense expense,
  ) async {
    final db = await database;

    return db.insert(
      'planned_expenses',
      expense.toMap(),
    );
  }

  Future<int> updatePlannedExpense(
    PlannedExpense expense,
  ) async {
    final db = await database;

    return db.update(
      'planned_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deletePlannedExpense(int id) async {
    final db = await database;

    return db.delete(
      'planned_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PlannedExpense>> getPlannedExpensesForMonth(
    DateTime month,
  ) async {
    await ensureRecurringExpensesForMonth(month);

    final db = await database;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final maps = await db.query(
      'planned_expenses',
      where: 'due_date >= ? AND due_date < ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'due_date ASC',
    );

    return maps.map(PlannedExpense.fromMap).toList();
  }

  Future<int> payPlannedExpense(
    PlannedExpense expense, {
    required DateTime paymentDate,
  }) async {
    if (expense.id == null) {
      throw ArgumentError(
        'La spesa prevista deve avere un id.',
      );
    }

    final db = await database;

    return db.transaction((txn) async {
      final transactionId = await txn.insert(
        'transactions',
        {
          'amount': expense.amount,
          'description': expense.name,
          'category': expense.category,
          'is_income': 0,
          'date': paymentDate.toIso8601String(),
        },
      );

      await txn.update(
        'planned_expenses',
        {
          'is_paid': 1,
          'paid_transaction_id': transactionId,
        },
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      return transactionId;
    });
  }

  // =====================================================
  // SPESE RICORRENTI MENSILI
  // =====================================================

  Future<int> insertRecurringExpense(
    RecurringExpense expense,
  ) async {
    final db = await database;

    final id = await db.insert(
      'recurring_expenses',
      expense.toMap(),
    );

    return id;
  }

  Future<int> updateRecurringExpense(
    RecurringExpense expense,
  ) async {
    if (expense.id == null) {
      throw ArgumentError(
        'La spesa ricorrente deve avere un id.',
      );
    }

    final db = await database;

    return db.transaction((txn) async {
      final result = await txn.update(
        'recurring_expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      // Le occorrenze non ancora pagate vengono rigenerate
      // usando i nuovi dati della ricorrenza.
      await txn.delete(
        'planned_expenses',
        where: 'recurring_expense_id = ? AND is_paid = 0',
        whereArgs: [expense.id],
      );

      return result;
    });
  }

  Future<int> deleteRecurringExpense(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      // Manteniamo le occorrenze già pagate perché sono collegate
      // a movimenti reali. Eliminiamo soltanto quelle future/non pagate.
      await txn.delete(
        'planned_expenses',
        where: 'recurring_expense_id = ? AND is_paid = 0',
        whereArgs: [id],
      );

      return txn.delete(
        'recurring_expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;

    final maps = await db.query(
      'recurring_expenses',
      orderBy: 'is_active DESC, day_of_month ASC, name ASC',
    );

    return maps.map(RecurringExpense.fromMap).toList();
  }

  Future<void> ensureRecurringExpensesForMonth(
    DateTime month,
  ) async {
    final db = await database;

    final targetMonth = DateTime(
      month.year,
      month.month,
      1,
    );

    final monthEnd = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final recurringMaps = await db.query(
      'recurring_expenses',
    );

    final recurringExpenses = recurringMaps
        .map(RecurringExpense.fromMap)
        .toList();

    final activeForMonth = recurringExpenses
        .where(
          (expense) => expense.isActiveForMonth(targetMonth),
        )
        .toList();

    final activeIds = activeForMonth
        .where((expense) => expense.id != null)
        .map((expense) => expense.id!)
        .toSet();

    await db.transaction((txn) async {
      final generatedForMonth = await txn.query(
        'planned_expenses',
        where:
            'recurring_expense_id IS NOT NULL AND due_date >= ? AND due_date < ?',
        whereArgs: [
          targetMonth.toIso8601String(),
          monthEnd.toIso8601String(),
        ],
      );

      // Se una ricorrenza è stata messa in pausa, terminata o eliminata,
      // togliamo dal mese soltanto l'occorrenza non ancora pagata.
      for (final row in generatedForMonth) {
        final recurringId = row['recurring_expense_id'] as int?;
        final isPaid = row['is_paid'] == 1;

        if (!isPaid &&
            recurringId != null &&
            !activeIds.contains(recurringId)) {
          await txn.delete(
            'planned_expenses',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      for (final recurring in activeForMonth) {
        if (recurring.id == null) continue;

        final existing = await txn.query(
          'planned_expenses',
          where:
              'recurring_expense_id = ? AND due_date >= ? AND due_date < ?',
          whereArgs: [
            recurring.id,
            targetMonth.toIso8601String(),
            monthEnd.toIso8601String(),
          ],
          limit: 1,
        );

        final dueDate = recurring.dueDateForMonth(targetMonth);

        if (existing.isEmpty) {
          await txn.insert(
            'planned_expenses',
            {
              'name': recurring.name,
              'amount': recurring.amount,
              'category': recurring.category,
              'due_date': dueDate.toIso8601String(),
              'is_paid': 0,
              'paid_transaction_id': null,
              'recurring_expense_id': recurring.id,
            },
          );
          continue;
        }

        if (existing.first['is_paid'] != 1) {
          await txn.update(
            'planned_expenses',
            {
              'name': recurring.name,
              'amount': recurring.amount,
              'category': recurring.category,
              'due_date': dueDate.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    });
  }

  // =====================================================
  // SPESE ANNUALI
  // =====================================================

  Future<int> insertAnnualExpense(
    AnnualExpense expense,
  ) async {
    final db = await database;

    return db.insert(
      'annual_expenses',
      expense.toMap(),
    );
  }

  Future<int> updateAnnualExpense(
    AnnualExpense expense,
  ) async {
    final db = await database;

    return db.update(
      'annual_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteAnnualExpense(int id) async {
    final db = await database;

    return db.delete(
      'annual_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AnnualExpense>> getAnnualExpenses() async {
    final db = await database;

    final maps = await db.query(
      'annual_expenses',
      orderBy: 'due_date ASC',
    );

    return maps.map(AnnualExpense.fromMap).toList();
  }

  Future<int> payAnnualExpense(
    AnnualExpense expense, {
    required DateTime paymentDate,
  }) async {
    if (expense.id == null) {
      throw ArgumentError(
        'La spesa annuale deve avere un id.',
      );
    }

    final db = await database;

    return db.transaction((txn) async {
      final transactionId = await txn.insert(
        'transactions',
        {
          'amount': expense.amount,
          'description': expense.name,
          'category': expense.category,
          'is_income': 0,
          'date': paymentDate.toIso8601String(),
        },
      );

      await txn.update(
        'annual_expenses',
        {
          'is_paid': 1,
          'paid_transaction_id': transactionId,
        },
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      return transactionId;
    });
  }
  // =====================================================
  // CATEGORIE PERSONALIZZABILI
  // =====================================================

  Future<List<ExpenseCategory>> getCategories({
    bool includeInactive = false,
  }) async {
    final db = await database;

    final maps = await db.query(
      'categories',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'is_protected ASC, sort_order ASC, name COLLATE NOCASE ASC',
    );

    return maps.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> insertCategory(ExpenseCategory category) async {
    final db = await database;

    final maxResult = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM categories WHERE is_protected = 0',
    );

    final nextOrder =
        (maxResult.first['max_order'] as num).toInt() + 1;

    final map = category.toMap();
    map.remove('id');
    map['sort_order'] = nextOrder;
    map['is_protected'] = 0;
    map['is_active'] = 1;

    return db.insert(
      'categories',
      map,
    );
  }

  Future<int> updateCategory(
    ExpenseCategory category, {
    required String oldName,
  }) async {
    if (category.id == null) {
      throw ArgumentError('La categoria deve avere un id.');
    }

    final db = await database;

    return db.transaction((txn) async {
      final existing = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [category.id],
        limit: 1,
      );

      if (existing.isEmpty) return 0;

      final isProtected = existing.first['is_protected'] == 1;
      final safeName =
          isProtected ? existing.first['name'] as String : category.name.trim();

      final result = await txn.update(
        'categories',
        {
          'name': safeName,
          'icon_key': category.iconKey,
          'color_value': category.colorValue,
          'is_active': isProtected ? 1 : (category.isActive ? 1 : 0),
          'sort_order': category.sortOrder,
          'is_protected': isProtected ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [category.id],
      );

      if (safeName != oldName) {
        for (final table in [
          'transactions',
          'annual_expenses',
          'planned_expenses',
          'recurring_expenses',
        ]) {
          await txn.update(
            table,
            {'category': safeName},
            where: 'category = ?',
            whereArgs: [oldName],
          );
        }
      }

      return result;
    });
  }

  Future<int> setCategoryActive(
    int id,
    bool isActive,
  ) async {
    final db = await database;

    final existing = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isEmpty) return 0;

    if (existing.first['is_protected'] == 1) {
      return 0;
    }

    return db.update(
      'categories',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  // =====================================================
  // IMPOSTAZIONI APP
  // =====================================================

  Future<void> setSetting(String key, String value) async {
    final db = await database;

    await db.insert(
      'app_settings',
      {
        'setting_key': key,
        'setting_value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;

    final result = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['setting_value'] as String?;
  }

  Future<void> setBoolSetting(String key, bool value) async {
    await setSetting(key, value ? '1' : '0');
  }

  Future<bool> getBoolSetting(
    String key, {
    bool defaultValue = false,
  }) async {
    final value = await getSetting(key);

    if (value == null) return defaultValue;
    return value == '1' || value.toLowerCase() == 'true';
  }


}
