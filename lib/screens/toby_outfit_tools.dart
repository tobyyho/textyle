import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../models/outfit_activity_store.dart';
import '../models/outfit_record.dart';
import '../models/outfit_store.dart';
import '../services/outfit_recommendation_service.dart';
import '../services/garment_media_store.dart';
import '../widgets/thread_messenger.dart';

const _teal = Color(0xFF0A8B79);
const _background = Color(0xFFF4F7FA);

/// Toby-styled Home entry to the existing local, metadata-only engine.
class TobyOutfitTools extends StatelessWidget {
  const TobyOutfitTools({super.key});

  Future<void> _suggest(BuildContext context) async {
    final inventory = context.read<InventoryStore>();
    await inventory.load();
    if (!context.mounted) return;
    final result = const OutfitRecommendationService().recommend(inventory.items);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.78),
        decoration: const BoxDecoration(color: _background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: ListView(shrinkWrap: true, children: [
          const Text('Outfit suggestions', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Local clothing-aware rules. Scores are not probabilities.'),
          const SizedBox(height: 12),
          if (result.suggestions.isEmpty)
            Text(result.message ?? 'Add an owned top and bottom to get suggestions.'),
          for (final suggestion in result.suggestions)
            Card(color: Colors.white, shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
              child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final entry in suggestion.garmentByRole.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      _SuggestionPhoto(reference: inventory.findById(entry.value)
                          ?.media.frontOriginal),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        '${enumWire(entry.key)}: ${inventory.findById(entry.value)?.name ?? 'Unavailable'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                    ]),
                  ),
                const SizedBox(height: 6),
                Text(suggestion.reasons.join(' · ')),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final names = suggestion.garmentByRole.values
                        .map((id) => inventory.findById(id)?.name ?? 'Unknown').join(' + ');
                    try {
                      await sheet.read<OutfitStore>().save(OutfitRecord(
                        id: 'outfit-${DateTime.now().microsecondsSinceEpoch}',
                        name: names,
                        garmentByRole: suggestion.garmentByRole,
                        garmentIds: suggestion.garmentByRole.values.toList(),
                      ));
                      if (sheet.mounted) Navigator.of(sheet).pop();
                    } on Object catch (error) {
                      if (sheet.mounted) ThreadMessenger.of(sheet).showSnackBar(
                        SnackBar(content: Text('Could not save outfit: $error')));
                    }
                  },
                  child: const Text('Save this outfit'),
                ),
              ])),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Your outfits', style: TextStyle(fontSize: 19,
          fontWeight: FontWeight.w800, color: Color(0xFF1D2228))),
      const SizedBox(height: 4),
      const Text('Find combinations from garments you saved.'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _suggest(context),
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('Suggest outfits'),
      ),
      TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const TobyPlanningPage())),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Plans & wear history'),
        style: TextButton.styleFrom(foregroundColor: _teal),
      ),
    ]),
  );
}

class _SuggestionPhoto extends StatelessWidget {
  const _SuggestionPhoto({required this.reference});
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    if (ref == null) return const SizedBox(
      width: 44, height: 44, child: Icon(Icons.checkroom_outlined));
    return FutureBuilder<Uint8List?>(
      future: context.read<GarmentMediaStore>().get(ref),
      builder: (context, snapshot) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 44, height: 44,
          child: snapshot.hasData && snapshot.data != null
            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
            : const Icon(Icons.checkroom_outlined)),
      ),
    );
  }
}

class TobyPlanningPage extends StatelessWidget {
  const TobyPlanningPage({super.key});

  Future<void> _plan(BuildContext context, OutfitRecord outfit) async {
    final selected = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (selected == null || !context.mounted) return;
    try {
      await context.read<OutfitActivityStore>().savePlan(
          CivilDate.fromLocal(selected), outfit.id);
    } on Object catch (error) {
      if (context.mounted) ThreadMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save plan: $error')));
    }
  }

  Future<void> _wear(BuildContext context, OutfitRecord outfit) async {
    try {
      await context.read<OutfitActivityStore>().saveWear(
          CivilDate.fromLocal(DateTime.now()), outfit.id);
    } on Object catch (error) {
      if (context.mounted) ThreadMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record wear: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitStore>();
    final activity = context.watch<OutfitActivityStore>();
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(title: const Text('Plans & wear history'),
          backgroundColor: _background),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          const Text('Saved outfits', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800)),
          if (outfits.outfits.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('Save an outfit suggestion to plan it.')),
          for (final outfit in outfits.outfits)
            Card(color: Colors.white, child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(outfit.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(onPressed: () => _plan(context, outfit),
                        child: const Text('Plan a date')),
                    OutlinedButton(onPressed: () => _wear(context, outfit),
                        child: const Text('Wore today')),
                  ]),
                ]),
            )),
          const SizedBox(height: 22),
          const Text('Plans', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800)),
          if (activity.plans.isEmpty) const Text('No plans yet.'),
          for (final plan in activity.plans)
            ListTile(title: Text(plan.date.wire),
                subtitle: Text(outfits.findById(plan.outfitId)?.name ??
                    'Outfit unavailable')),
          const SizedBox(height: 22),
          const Text('Wear history', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w800)),
          if (activity.wears.isEmpty) const Text('No wear entries yet.'),
          for (final wear in activity.wears)
            ListTile(title: Text(wear.date.wire),
                subtitle: Text(wear.outfitNameSnapshot)),
        ],
      ),
    );
  }
}
