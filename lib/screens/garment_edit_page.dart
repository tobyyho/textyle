import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clothing_item.dart';
import '../models/inventory_store.dart';
import '../services/garment_metadata_edit.dart';
import '../services/garment_presentation.dart';
import 'garment_photo_card.dart';

class GarmentEditPage extends StatefulWidget {
  const GarmentEditPage({super.key, required this.itemId});
  final String itemId;
  @override
  State<GarmentEditPage> createState() => _GarmentEditPageState();
}

class _GarmentEditPageState extends State<GarmentEditPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late GarmentCategory _category;
  late String _colour;
  late GarmentPattern _pattern;
  late Set<Season> _seasons;
  bool _saving = false;
  String? _error;
  ClothingItem? _initial;
  @override
  void initState() {
    super.initState();
    _initial = context.read<InventoryStore>().findById(widget.itemId);
    _name = TextEditingController(text: _initial == null ? '' : garmentDisplayName(_initial!));
    _category = _initial?.classification.category ?? GarmentCategory.unknown;
    _colour = _initial?.attributes.primaryColor ?? 'unknown';
    _pattern = _initial?.attributes.pattern ?? GarmentPattern.unknown;
    _seasons = {...?_initial?.attributes.seasons};
  }
  @override
  void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final store = context.read<InventoryStore>();
    final current = store.findById(widget.itemId);
    if (current == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      await store.updateItem(editGarmentMetadata(current, name: _name.text,
        category: _category, colour: _colour, pattern: _pattern, seasons: _seasons));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  InputDecoration _field(String label) => InputDecoration(labelText: label,
    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.all(18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E9ED))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E9ED))));

  @override
  Widget build(BuildContext context) {
    final item = _initial;
    if (item == null) return Scaffold(appBar: AppBar(title: const Text('Edit garment')), body: const Center(child: Text('This garment is no longer available.')));
    final colours = <String>{'black','white','grey','blue','red','green','yellow','orange','pink','purple','brown','beige_or_cream','multicolour','unknown',_colour};
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(title: const Text('Edit garment', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        centerTitle: true, backgroundColor: const Color(0xFFF4F7FA), surfaceTintColor: Colors.transparent),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24,12,24,20),
        child: SizedBox(height: 52, child: FilledButton.icon(onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving…' : 'Save changes'))))),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
        child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('Make it yours', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.7)),
          const SizedBox(height: 6),
          const Text('Update the details in your closet.', style: TextStyle(color: Color(0xFF7C858E), height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: GarmentPhotoCard(reference: item.media.frontNormalized ?? item.media.frontOriginal, label: 'Front')),
            const SizedBox(width: 14), Expanded(child: GarmentPhotoCard(reference: item.media.backNormalized ?? item.media.backOriginal, label: 'Back'))]),
          const SizedBox(height: 28),
          TextFormField(controller: _name, decoration: _field('Garment name'), maxLength: 80,
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a garment name' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<GarmentCategory>(initialValue: _category, isExpanded: true, decoration: _field('Category'),
            items: GarmentCategory.values.map((v) => DropdownMenuItem(value: v, child: Text(garmentCategoryLabel(v)))).toList(),
            onChanged: _saving ? null : (v) => setState(() => _category = v ?? _category)),
          if (_category != item.classification.category) ...[
            const SizedBox(height: 8), const Text('Changing category requires a new 3D preview.', style: TextStyle(color: Color(0xFF7C858E), fontSize: 12))],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: _colour, isExpanded: true, decoration: _field('Colour'),
            items: colours.map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ')))).toList(),
            onChanged: _saving ? null : (v) => setState(() => _colour = v ?? _colour)),
          const SizedBox(height: 16),
          DropdownButtonFormField<GarmentPattern>(initialValue: _pattern, isExpanded: true, decoration: _field('Pattern'),
            items: GarmentPattern.values.map((v) => DropdownMenuItem(value: v, child: Text(enumWire(v).replaceAll('_',' ')))).toList(),
            onChanged: _saving ? null : (v) => setState(() => _pattern = v ?? _pattern)),
          const SizedBox(height: 24),
          const Text('Seasons', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: Season.values.map((v) => FilterChip(
            label: Text(enumWire(v)), selected: _seasons.contains(v),
            onSelected: _saving ? null : (selected) => setState(() { if (selected) { _seasons.add(v); } else { _seasons.remove(v); } }))).toList()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ])))),
    );
  }
}
