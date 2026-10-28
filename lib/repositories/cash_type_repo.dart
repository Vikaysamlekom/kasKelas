import '../database/db_helper.dart';
import '../models/cash_type_model.dart';
import 'siswa_repo.dart';

/// Repository data jenis kas / iuran (cash_types).
class CashTypeRepository {
  final DBHelper _db = DBHelper.instance;

  Future<List<CashTypeModel>> list({bool onlyActive = false}) async {
    final String where = onlyActive ? 'WHERE is_active = 1' : '';
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT * FROM cash_types $where ORDER BY name ASC',
    );
    return rows.map(CashTypeModel.fromMap).toList();
  }

  Future<CashTypeModel?> getById(int id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      DBHelper.tblCashTypes,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : CashTypeModel.fromMap(rows.first);
  }

  Future<CashTypeModel> save({
    int? id,
    required String name,
    required String code,
    required int amount,
    required String frequency,
    required int dueDay,
    String? description,
  }) async {
    final String now = DateTime.now().toIso8601String();
    if (id == null) {
      final int newId = await _db.insert(
        DBHelper.tblCashTypes,
        <String, Object?>{
          'name': name.trim(),
          'code': code.trim().toUpperCase(),
          'amount': amount,
          'frequency': frequency,
          'due_day': dueDay,
          'description': description,
          'is_active': 1,
          'created_at': now,
        },
      );
      return CashTypeModel(
        id: newId,
        name: name.trim(),
        code: code.trim().toUpperCase(),
        amount: amount,
        frequency: frequency,
        dueDay: dueDay,
        description: description,
        createdAt: DateTime.now(),
      );
    }
    await _db.update(
      DBHelper.tblCashTypes,
      <String, Object?>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'amount': amount,
        'frequency': frequency,
        'due_day': dueDay,
        'description': description,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    final List<Map<String, Object?>> rows = await _db.query(
      DBHelper.tblCashTypes,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Jenis kas tidak ditemukan.');
    }
    return CashTypeModel.fromMap(rows.first);
  }

  /// Hapus jenis kas. Jika sudah dipakai transaksi pembayaran →
  /// nonaktifkan (soft delete).
  Future<DeleteResult> delete(int id) async {
    final int paymentCount = await _db.count(
      DBHelper.tblPayments,
      where: 'cash_type_id = ?',
      whereArgs: <Object?>[id],
    );
    if (paymentCount > 0) {
      final int updated = await _db.update(
        DBHelper.tblCashTypes,
        <String, Object?>{'is_active': 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return DeleteResult.fromUpdate(updated);
    }
    await _db.delete(
      DBHelper.tblCashTypes,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return const DeleteResult.deleted();
  }

  Future<bool> nameExists(String name, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM cash_types WHERE name = ? AND id != ?',
      <Object?>[name.trim(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }

  Future<bool> codeExists(String code, {int? excludeId}) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT id FROM cash_types WHERE code = ? AND id != ?',
      <Object?>[code.trim().toUpperCase(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }
}
