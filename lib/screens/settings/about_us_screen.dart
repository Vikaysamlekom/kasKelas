import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const List<String> _anggotaKelompok = <String>[
    'Achmad Refaldi Peto',
    'Agustina Febriyanti',
    'Aprizal Dwi Lutfiansah',
    'Evan Hardyansyah',
    'Muhamad Reinaldi Putra Ramadhani',
    'Muhammad Susilo',
    'Phundut Bagas Wazidan',
    'Rangga Waridat',
    'Usep Saeful Adzkia',
    'Vickry Dwi Prasetyanto',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 24),
          _sectionHeading('Informasi aplikasi'),
          const SizedBox(height: 10),
          _buildAppInformation(),
          const SizedBox(height: 24),
          _sectionHeading('Kelompok pengabdi'),
          const SizedBox(height: 10),
          _buildCommunityServiceCard(),
          const SizedBox(height: 24),
          _sectionHeading('Tentang aplikasi'),
          const SizedBox(height: 10),
          _buildDescriptionCard(),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Terima kasih kepada SMK Bintang Nusantara atas kesempatan '
              'untuk berkolaborasi melalui kegiatan pengabdian ini.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navy, AppColors.navySoft],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'INFORMASI APLIKASI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Solusi pencatatan kas siswa untuk mendukung administrasi '
            'sekolah yang lebih tertib dan mudah dipantau.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Text(title, style: AppText.sectionTitle.copyWith(fontSize: 16));
  }

  Widget _buildAppInformation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: <Widget>[
            _informationRow(
              icon: Icons.apps_rounded,
              label: 'Nama aplikasi',
              value: AppConstants.appName,
            ),
            const Divider(height: 1, indent: 44),
            _informationRow(
              icon: Icons.new_releases_outlined,
              label: 'Versi',
              value: AppConstants.appVersion,
            ),
          ],
        ),
      ),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 21, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.caption),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityServiceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: AppColors.navy,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Universitas Pamulang', style: AppText.sectionTitle),
                      SizedBox(height: 3),
                      Text(
                        'Kelompok pengabdian kepada masyarakat',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'Aplikasi ini merupakan hasil kolaborasi kelompok pengabdi '
              'Universitas Pamulang bersama SMK Bintang Nusantara. '
              'Terima kasih atas dedikasi dan kerja sama seluruh pihak '
              'yang telah mendukung kegiatan ini.',
              style: AppText.bodySmall.copyWith(height: 1.55),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'Anggota kelompok',
              style: AppText.label.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < _anggotaKelompok.length; i++) ...<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 28,
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.navy,
                  size: 21,
                ),
                title: Text(
                  _anggotaKelompok[i],
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
              ),
              if (i < _anggotaKelompok.length - 1)
                const Divider(height: 1, indent: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Kas Bintang Nusantara', style: AppText.sectionTitle),
            const SizedBox(height: 8),
            Text(
              'dirancang untuk membantu bendahara SMK Bintang Nusantara '
              'mengelola administrasi kas siswa. Aplikasi menyediakan '
              'pencatatan pembayaran, pemantauan tunggakan, pengelolaan '
              'pengeluaran, serta penyusunan laporan.',
              style: AppText.body.copyWith(height: 1.55),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.offline_bolt_outlined,
                    color: AppColors.teal,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Dapat digunakan secara offline. Data operasional '
                      'disimpan secara lokal pada perangkat.',
                      style: AppText.bodySmall.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
