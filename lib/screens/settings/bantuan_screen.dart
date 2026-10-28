import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BantuanScreen extends StatefulWidget {
  const BantuanScreen({super.key});

  @override
  State<BantuanScreen> createState() => _BantuanScreenState();
}

class _BantuanScreenState extends State<BantuanScreen> {
  static const String _email = 'ranggawaridat@gmail.com';
  static const String _subject = 'Bantuan Aplikasi Kas Bintang Nusantara';
  static const String _body = '''
Halo, saya ingin meminta bantuan terkait aplikasi Kas Bintang Nusantara.

Nama:
Sekolah/Kelas:
Perangkat:
Versi aplikasi:

Kendala atau pertanyaan:

Langkah yang sudah dicoba:

Terima kasih.''';

  late final TextEditingController _messageController = TextEditingController(
    text: _body,
  );

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _kirimEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: <String, String>{
        'subject': _subject,
        'body': _messageController.text,
      },
    );

    try {
      final bool opened = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!opened) {
        _tampilkanPesan(
          context,
          'Aplikasi email tidak ditemukan di perangkat ini.',
        );
      }
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      _tampilkanPesan(
        context,
        'Tidak dapat membuka aplikasi email: ${error.message ?? error.code}',
      );
    } on MissingPluginException {
      if (!context.mounted) return;
      _tampilkanPesan(context, 'Fitur email tidak tersedia di perangkat ini.');
    }
  }

  void _tampilkanPesan(BuildContext context, String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Icon(
            Icons.support_agent_outlined,
            size: 48,
            color: Color(0xFF173B63),
          ),
          const SizedBox(height: 12),
          Text(
            'Butuh bantuan?',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Jelaskan kendala atau pertanyaan Anda. Pesan dapat diedit sebelum '
            'dikirim agar kami dapat membantu dengan lebih cepat.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Pesan bantuan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            minLines: 8,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Tulis kendala atau pertanyaan Anda',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _kirimEmail(context),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Kirim Email'),
          ),
        ],
      ),
    );
  }
}
