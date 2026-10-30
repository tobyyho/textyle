import 'package:flutter/material.dart';
import '../models/inventory_store.dart';
import '../models/clothing_item.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  ClothingType filter = ClothingType.top;

  @override
  Widget build(BuildContext context) {
    final filtered = InventoryStore.items
        .where((item) => item.type == filter)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            SegmentedButton<ClothingType>(
              segments: const [
                ButtonSegment(value: ClothingType.top, label: Text('Tops')),
                ButtonSegment(value: ClothingType.bottom, label: Text('Bottoms')),
                ButtonSegment(value: ClothingType.accessory, label: Text('Accessories')),
              ],
              selected: {filter},
              onSelectionChanged: (set) {
                setState(() {
                  filter = set.first;
                });
              },
            ),

            const SizedBox(height: 20),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No items yet'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.black12,
                                child: Text(item.color[0]),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(item.color,
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}