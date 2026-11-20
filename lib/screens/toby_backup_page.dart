import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/core_backup.dart';
import '../services/core_backup_platform.dart';
import '../services/garment_media_store.dart';

/// Toby-styled entry to the unchanged validated CORE archive format.
class TobyBackupPage extends StatefulWidget {
  const TobyBackupPage({super.key});
  @override
  State<TobyBackupPage> createState() => _TobyBackupPageState();
}

class _TobyBackupPageState extends State<TobyBackupPage> {
  bool busy = false;
  bool restored = false;
  String? message;

  CoreBackup get backup => createCoreBackup(context.read<GarmentMediaStore>());

  Future<void> _export() async {
    setState(() { busy = true; message = null; });
    try {
      final bytes = await backup.export();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      downloadCoreBackup(bytes, 'textyle-core-backup-$date.json');
      if (mounted) setState(() => message = 'Backup downloaded. Store it privately.');
    } on Object catch (error) {
      if (mounted) setState(() => message = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    setState(() { busy = true; message = null; });
    try {
      final Uint8List? bytes = await pickCoreBackup();
      if (bytes == null || !mounted) return;
      final parsed = CoreBackup.parse(bytes);
      final replace = await showDialog<bool>(context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Replace local Textyle data?'),
          content: Text('This validated backup contains ${parsed.inventory.length} garments, '
              '${parsed.outfits.length} outfits and ${parsed.media.length} image assets. '
              'Restoring replaces this browser’s wardrobe, outfits and history. '
              'Export the current data first if you may need it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Replace and restore')),
          ],
        ));
      if (replace != true || !mounted) return;
      await backup.restore(bytes);
      if (mounted) setState(() {
        restored = true;
        message = 'Restore complete. Reload to use the restored wardrobe.';
      });
    } on Object catch (error) {
      if (mounted) setState(() => message = 'Restore failed: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FA),
    appBar: AppBar(title: const Text('Backup & restore'),
        backgroundColor: const Color(0xFFF4F7FA)),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(30)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Keep your wardrobe safe', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Clothing photos and records live in this browser. '
                  'The backup excludes API credentials. Experimental 3D '
                  'approvals are separate and are not restored by CORE backup.'),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export backup')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: busy ? null : _import,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Import and replace')),
              if (busy) const LinearProgressIndicator(),
              if (message != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(message!, key: const ValueKey('backup-result')),
              ),
              if (restored) FilledButton(onPressed: reloadCoreApp,
                  child: const Text('Reload restored wardrobe')),
            ],
          ),
        ),
      ],
    ),
  );
}
