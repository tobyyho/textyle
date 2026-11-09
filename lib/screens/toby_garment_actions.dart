import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../models/outfit_store.dart';
import '../services/garment_media_store.dart';
import 'm11_development_preview.dart';
import 'm11_generation_request_panel.dart';
import 'm11_operator_authority.dart';
import 'm11_saved_association.dart';
import 'm11_saved_registry.dart';
import 'tailor_garment_flow.dart';

/// Small actions placed in Toby's existing garment detail sheets. The canonical
/// record remains the authority; a verified M11 action is optional and fail-closed.
class TobyGarmentActions extends StatelessWidget {
  const TobyGarmentActions(this.itemId, {super.key});
  final String itemId;

  Future<M11SavedAssociation?> _approved(
      BuildContext context, ClothingItem item) async {
    if (!m11DevelopmentPreviewEnabled || item.media.frontOriginal == null) {
      return null;
    }
    try {
      final media = context.read<GarmentMediaStore>();
      final front = await media.get(item.media.frontOriginal!);
      final back = item.media.backOriginal == null
          ? null : await media.get(item.media.backOriginal!);
      final association = M11SavedAssociation.resolve(
          m11ReadSavedAssociation(), item, front, back);
      if (association == null) return null;
      final authority = await M11OperatorAuthority.fetch();
      return authority?.approves(association) == true ? association : null;
    } on Object {
      return null;
    }
  }

  Future<void> _delete(BuildContext context, ClothingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete garment?'),
        content: Text('Remove “${item.name}” from this local wardrobe?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<OutfitStore>().removeGarment(item.id);
    await context.read<InventoryStore>().removeItem(item.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = context.watch<InventoryStore>().findById(itemId);
    if (item == null || item.source.type == GarmentSourceType.catalogue) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 14),
      if (item.media.frontOriginal != null)
        Row(children: [
          Expanded(child: _SavedPhoto(item.media.frontOriginal!, 'Front')),
          const SizedBox(width: 10),
          Expanded(child: item.media.backOriginal == null
              ? const SizedBox.shrink()
              : _SavedPhoto(item.media.backOriginal!, 'Back')),
        ]),
      const SizedBox(height: 12),
      Text('Category: ${enumWire(item.classification.category).replaceAll('_', ' ')}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      Text('Colour: ${item.attributes.primaryColor ?? item.colorLabel}'),
      if (item.classification.confidence != null)
        Text('Tailor confidence: ${item.classification.confidence!.toStringAsFixed(2)}'),
      if (item.classification.abstained)
        const Text('AI prediction uncertain — review required.'),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TailorGarmentFlow(existingItem: item))),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit garment'),
      ),
      if (m11DevelopmentPreviewEnabled && item.media.frontOriginal != null)
        FutureBuilder<M11SavedAssociation?>(
          future: _approved(context, item),
          builder: (context, snapshot) {
            final association = snapshot.data;
            if (association == null) return const SizedBox.shrink();
            return FilledButton.icon(
              onPressed: () {
                if (context.read<InventoryStore>().findById(itemId) == null) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => M11DevelopmentPreviewPage(
                      savedItemId: association.itemId,
                      savedImageSha256: association.imageSha256,
                      savedBackImageSha256: association.backImageSha256,
                      savedAssetId: association.assetId,
                      savedGlbSha256: association.glbSha256,
                    )));
              },
              icon: const Icon(Icons.view_in_ar_outlined),
              label: const Text('3D Preview (Experimental)'),
            );
          },
        ),
      if (m11DevelopmentPreviewEnabled)
        M11GenerationRequestPanel(item),
      TextButton.icon(
        onPressed: () => _delete(context, item),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete garment'),
      ),
    ]);
  }
}

class _SavedPhoto extends StatelessWidget {
  const _SavedPhoto(this.reference, this.label);
  final String reference;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
    FutureBuilder<Uint8List?>(
      future: context.read<GarmentMediaStore>().get(reference),
      builder: (context, snapshot) => Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FA),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: snapshot.data == null
            ? const Center(child: Icon(Icons.image_not_supported_outlined))
            : Image.memory(snapshot.data!, fit: BoxFit.contain),
      ),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]);
}
