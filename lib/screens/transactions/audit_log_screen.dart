import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/audit_log_model.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';

/// Halaman jejak audit (semua aksi tercatat di database).
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadAudit();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    context.read<TransactionProvider>().loadAudit(search: value);
  }

  @override
  Widget build(BuildContext context) {
    final TransactionProvider provider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              _searchController.clear();
              provider.loadAudit();
            },
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Cari aktivitas / aksi / tabel...',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _AuditList(
                isLoading: provider.isLoadingAudit,
                logs: provider.auditLogs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  final bool isLoading;
  final List<AuditLogModel> logs;

  const _AuditList({required this.isLoading, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (isLoading && logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Belum ada aktivitas',
        message: 'Semua aksi pada aplikasi akan tercatat di sini.',
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => context.read<TransactionProvider>().loadAudit(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final AuditLogModel log = logs[index];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _actionColor(log.action).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _actionIcon(log.action),
                    size: 20,
                    color: _actionColor(log.action),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        log.description ?? log.action,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_actionLabel(log.action, log.entityTable)} · '
                        '${log.officerName ?? 'System'}',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formatters.tanggalWaktuIso(
                          log.createdAt.toIso8601String(),
                        ),
                        style: AppText.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static IconData _actionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Icons.login_rounded;
      case 'logout':
        return Icons.logout_rounded;
      case 'tambah':
        return Icons.add_circle_outline;
      case 'ubah':
        return Icons.edit_outlined;
      case 'hapus':
        return Icons.delete_outline;
      case 'masuk':
        return Icons.arrow_downward_rounded;
      case 'keluar':
        return Icons.arrow_upward_rounded;
      case 'batal':
        return Icons.block_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  static Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'tambah':
      case 'masuk':
        return AppColors.teal;
      case 'ubah':
        return AppColors.blue;
      case 'hapus':
      case 'batal':
        return AppColors.danger;
      case 'keluar':
        return AppColors.orange;
      case 'login':
      case 'logout':
        return AppColors.navy;
      default:
        return AppColors.textMuted;
    }
  }

  static String _actionLabel(String action, String table) {
    final String a = action.toLowerCase();
    final String t = table.replaceAll('_', ' ');
    switch (a) {
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'tambah':
        return 'Tambah $t';
      case 'ubah':
        return 'Ubah $t';
      case 'hapus':
        return 'Hapus $t';
      case 'masuk':
        return 'Pembayaran masuk';
      case 'keluar':
        return 'Pengeluaran';
      case 'batal':
        return 'Pembatalan';
      default:
        return '${a[0].toUpperCase()}${a.substring(1)} $t';
    }
  }
}