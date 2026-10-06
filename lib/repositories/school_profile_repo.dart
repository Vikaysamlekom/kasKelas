import '../database/db_helper.dart';
import '../models/school_profile_model.dart';

/// Repository untuk mengelola profil sekolah.
class SchoolProfileRepository {
  final DBHelper _db = DBHelper.instance;

  static const String _table = DBHelper.tblSchoolProfile;

  Future<SchoolProfileModel?> getProfile() async {
    final List<Map<String, Object?>> rows = await _db.query(_table);
    if (rows.isEmpty) return null;
    return SchoolProfileModel.fromMap(rows.first);
  }

  Future<SchoolProfileModel> saveProfile(SchoolProfileModel profile) async {
    final String now = DateTime.now().toIso8601String();
    final Map<String, Object?> data = <String, Object?>{
      ...profile.toMap(),
      'updated_at': now,
    };
    final SchoolProfileModel? existing = await getProfile();
    if (existing == null) {
      final int id = await _db.insert(_table, <String, Object?>{...data});
      return SchoolProfileModel.fromMap(<String, Object?>{...data, 'id': id});
    }
    await _db.update(_table, data, where: 'id = ?', whereArgs: <Object?>[existing.id]);
    return SchoolProfileModel.fromMap(<String, Object?>{
      ...data,
      'id': existing.id,
    });
  }
}
