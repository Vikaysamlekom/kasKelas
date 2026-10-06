import 'package:flutter/foundation.dart';

import '../database/db_helper.dart';
import '../models/cash_type_model.dart';
import '../repositories/cash_type_repo.dart';
import '../repositories/siswa_repo.dart';

/// Provider data jenis kas / iuran.
class CashTypesProvider extends ChangeNotifier {
  final CashTypeRepository cashTypeRepository;

  CashTypesProvider({required this.cashTypeRepository});

  List<CashTypeModel> _cashTypes = <CashTypeModel>[];
  bool _isLoading = false;
  String? _error;

  List<CashTypeModel> get cashTypes => _cashTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cashTypes = await cashTypeRepository.list();
    } catch (e) {
      _error = 'Gagal memuat jenis kas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> save({
    int? id,
    required String name,
    required String code,
    required int amount,
    required String frequency,
    required int dueDay,
    String? description,
    int? userId,
  }) async {
    final CashTypeModel saved = await cashTypeRepository.save(
      id: id,
      name: name,
      code: code,
      amount: amount,
      frequency: frequency,
      dueDay: dueDay,
      description: description,
    );
    await DBHelper.instance.logAudit(
      userId: userId,
      action: id == null ? 'tambah' : 'ubah',
      entityTable: 'cash_types',
      entityId: saved.id,
      description: '${id == null ? 'Tambah' : 'Ubah'} jenis kas ${saved.name}',
    );
    await load();
  }

  Future<DeleteResult> delete(int id, {int? userId}) async {
    final DeleteResult result = await cashTypeRepository.delete(id);
    await DBHelper.instance.logAudit(
      userId: userId,
      action: 'hapus',
      entityTable: 'cash_types',
      entityId: id,
      description: result.isDeactivated ? 'Nonaktifkan jenis kas id=$id' : 'Hapus jenis kas id=$id',
    );
    await load();
    return result;
  }
}