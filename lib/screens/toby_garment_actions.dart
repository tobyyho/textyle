
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
import 'garment_edit_page.dart';
import 'garment_photo_card.dart';
import '../services/garment_presentation.dart';
import 'tshirt_texture_page.dart';
import '../services/tshirt_projection.dart';
import '../services/automatic_template_registry.dart';
import '../widgets/thread_messenger.dart';

/// Small actions placed in Toby's existing garment detail sheets. The canonical
/// record remains the authority; a verified M11 action is optional and fail-closed.
class TobyGarmentActions extends StatelessWidget {
  const TobyGarmentActions(this.itemId, {super.key, this.bodyProfile});
  final String itemId;
  final String? bodyProfile;

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
      const SizedBox(height: 24),
      const Text('Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: GarmentPhotoCard(reference: item.media.frontNormalized ?? item.media.frontOriginal, label: 'Front')),
        const SizedBox(width: 14),
        Expanded(child: GarmentPhotoCard(reference: item.media.backNormalized ?? item.media.backOriginal, label: 'Back')),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text(garmentCategoryLabel(item.classification.category)), side: BorderSide.none,
          backgroundColor: const Color(0xFFF4F7FA)),
        if (item.attributes.primaryColor != null && item.attributes.primaryColor != 'unknown')
          Chip(label: Text(item.attributes.primaryColor!.replaceAll('_', ' ')), side: BorderSide.none,
            backgroundColor: const Color(0xFFF4F7FA)),
      ]),
      if (item.classification.abstained)
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Check the category before using this garment in an outfit.')),
      if (item.digital3D.status == AssetStatus.ready && isAutomaticPhotoTemplateVersion(item.digital3D.templateVersion))
        const Padding(padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text('3D preview ready', style: TextStyle(color: Color(0xFF008F7D), fontSize: 13))),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
            builder: (_) => GarmentEditPage(itemId: item.id))),
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
      const SizedBox(height: 10),
      if (photoTshirtEligible(item, bodyProfile))
        OutlinedButton.icon(
          onPressed: () async {
            final saved = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
                builder: (_) => TshirtTexturePage(item: item)));
            if (saved == true && context.mounted) {
              // Close the old detail sheet; its WardrobeItem snapshot predates
              // generation. The inventory rebuilds from the saved canonical item.
              final messenger = ThreadMessenger.of(context);
              Navigator.of(context).pop();
              messenger.showSnackBar(const SnackBar(
                content: Text('Textured T-shirt saved. Select it from your closet to preview it on the avatar.'),
              ));
            }
          },
          icon: const Icon(Icons.checkroom_outlined),
          label: Text(item.digital3D.templateVersion == photoTshirtVersion || item.digital3D.templateVersion == autoPhotoTshirtVersion
              ? 'Adjust 3D preview' : 'Create 3D preview'),
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFAD4C4C)),
        onPressed: () => _delete(context, item),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete garment'),
      ),
    ]);
  }
}
