import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/garment_media_store.dart';

class GarmentPhotoCard extends StatelessWidget {
  const GarmentPhotoCard({super.key, required this.reference, required this.label});
  final String? reference;
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ClipRRect(borderRadius: BorderRadius.circular(20), child: Container(
      color: const Color(0xFFF4F7FA), height: 156, width: double.infinity,
      child: reference == null ? const Center(child: Icon(Icons.checkroom_outlined, color: Color(0xFF7C858E)))
        : FutureBuilder<Uint8List?>(future: context.read<GarmentMediaStore>().get(reference!),
            builder: (context, snapshot) => snapshot.data != null
              ? Image.memory(snapshot.data!, fit: BoxFit.contain)
              : Center(child: snapshot.connectionState == ConnectionState.waiting
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Icon(Icons.image_not_supported_outlined, color: Color(0xFF7C858E)))),
    )),
    const SizedBox(height: 8),
    Text(label, style: const TextStyle(color: Color(0xFF7C858E), fontSize: 13, fontWeight: FontWeight.w500)),
  ]);
}
