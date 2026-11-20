import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/core_backup.dart';
import '../services/core_backup_platform.dart';
import '../services/garment_media_store.dart';

class CoreBackupPage extends StatefulWidget {
  const CoreBackupPage({super.key});
  @override
  State<CoreBackupPage> createState() => _CoreBackupPageState();
}

class _CoreBackupPageState extends State<CoreBackupPage> {
  bool busy = false;
  String? message;
  bool restored = false;

  CoreBackup _backup() => createCoreBackup(context.read<GarmentMediaStore>());

  Future<void> _export() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final bytes = await _backup().export();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      downloadCoreBackup(bytes, 'textyle-core-backup-$date.json');
      if (mounted)
        setState(() => message =
            'Backup download started. Keep this file somewhere safe.');
    } on Object catch (error) {
      if (mounted) setState(() => message = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    Uint8List? bytes;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      bytes = await pickCoreBackup();
      if (bytes == null || !mounted) return;
      final preview = CoreBackup.parse(bytes);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace this browser’s Textyle data?'),
          content: Text(
              'The backup contains ${preview.inventory.length} garments, '
              '${preview.outfits.length} outfits, ${preview.media.length} media files, '
              '${(preview.activity['plans'] as List).length} plans and '
              '${(preview.activity['wears'] as List).length} wear entries. '
              'This will replace the current wardrobe, outfits and history in this browser. '
              'Export the current data first if you may need it later.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Replace and restore')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _backup().restore(bytes);
      if (mounted)
        setState(() {
          restored = true;
          message = 'Restore complete. Reload to open the restored wardrobe.';
        });
    } on Object catch (error) {
      if (mounted) setState(() => message = 'Restore failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Backup & restore')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              const Text('Your wardrobe is stored in this browser',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  'Clearing browser storage or changing profiles can erase local data. '
                  'Export a backup and keep it in a safe place. Backups contain your garment photos; '
                  'they do not contain Tailor API credentials.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: busy ? null : _export,
                  icon: const Icon(Icons.download),
                  label: const Text('Export local backup')),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                  onPressed: busy ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import and replace local data')),
              const SizedBox(height: 12),
              const Text(
                  'Import validates the backup before asking for confirmation. '
                  'There is no merge: a successful restore replaces this browser’s CORE wardrobe, '
                  'outfits, plans and wear history. Experimental 3D assets are included only when '
                  'their local bytes are available; export stops rather than silently omitting them.'),
              if (busy)
                const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: LinearProgressIndicator()),
              if (message != null)
                Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child:
                        Text(message!, key: const ValueKey('backup-result'))),
              if (restored)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton(
              onPressed: reloadCoreApp,
                        child: const Text('Reload restored wardrobe'))),
            ]),
      );
}
