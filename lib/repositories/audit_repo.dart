import '../database/db_helper.dart';
import '../models/audit_log_model.dart';

/// Repository jejak audit (audit_logs + join users).
class AuditLogRepository {
  final DBHelper _db = DBHelper.instance;

  /// Semua aktivitas, terbaru dulu. `search` menyaring teks deskripsi,
  /// aksi, atau tabel entitas.
  Future<List<AuditLogModel>> list({String? search}) async {
    final List<String> where = <String>['1=1'];
    final List<Object?> args = <Object?>[];
    final String? q = search?.trim();
    if (q != null && q.isNotEmpty) {
      where.add('(a.description LIKE ? OR a.action LIKE ? '
          'OR a.entity_table LIKE ?)');
      final String like = '%$q%';
      args.addAll(<Object?>[like, like, like]);
    }

    final List<Map<String, Object?>> rows = await _db.rawQuery(
      '''
      SELECT a.*, u.full_name
      FROM ${DBHelper.tblAuditLogs} a
      LEFT JOIN ${DBHelper.tblUsers} u ON u.id = a.user_id
      WHERE ${where.join(' AND ')}
      ORDER BY a.created_at DESC
      LIMIT 500
      ''',
      args,
    );
    return rows.map(AuditLogModel.fromMap).toList();
  }
}