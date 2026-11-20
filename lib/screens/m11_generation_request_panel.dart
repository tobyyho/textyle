import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clothing_item.dart';
import '../services/garment_media_store.dart';
import 'm11_generation_request.dart';
import 'm11_operator_authority.dart';
import 'm11_request_registry.dart';
import 'm11_saved_association.dart';
import 'm11_saved_registry.dart';
import '../widgets/thread_messenger.dart';

/// A development-only request UI. Nothing here starts the operator pipeline.
class M11GenerationRequestPanel extends StatefulWidget {
  const M11GenerationRequestPanel(this.item, {super.key});
  final ClothingItem item;

  @override
  State<M11GenerationRequestPanel> createState() => _M11GenerationRequestPanelState();
}

class _M11GenerationRequestPanelState extends State<M11GenerationRequestPanel> {
  Future<_RequestView>? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view ??= _load();
  }

  @override
  void didUpdateWidget(covariant M11GenerationRequestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.media.frontOriginal != widget.item.media.frontOriginal ||
        oldWidget.item.media.backOriginal != widget.item.media.backOriginal) {
      _refresh();
    }
  }

  void _refresh() => setState(() => _view = _load());

  Future<_RequestView> _load() async {
    final item = widget.item;
    if (!M11GenerationRequest.eligibleCandidate(item)) {
      return const _RequestView(null, null, null, false);
    }
    try {
      final media = context.read<GarmentMediaStore>();
      final front = await media.get(item.media.frontOriginal!);
      final back = await media.get(item.media.backOriginal!);
      if (front == null || back == null) return const _RequestView(null, null, null, false);
      final record = M11GenerationRequest.latestForItem(
          m11ReadGenerationRequests(), item.id);
      final valid = record == null || record.matches(item, front, back);
      final association = M11SavedAssociation.resolve(
          m11ReadSavedAssociation(), item, front, back);
      final authority = record != null || association != null
          ? await M11OperatorAuthority.fetch() : null;
      final approvedModel = association != null &&
          authority?.approves(association) == true;
      final verifiedStatus = record != null && valid
          ? authority?.verifiedStatus(record, approvedModel ? association : null)
          : null;
      return _RequestView(front, back, record, valid,
          status: verifiedStatus, hasPreviousModel: approvedModel);
    } on Object {
      return const _RequestView(null, null, null, false);
    }
  }

  Future<void> _request(_RequestView view) async {
    if (view.front == null || view.back == null) return;
    try {
      final record = M11GenerationRequest.create(widget.item, view.front!, view.back!);
      m11WriteGenerationRequests(
          M11GenerationRequest.append(m11ReadGenerationRequests(), record));
      if (mounted) _refresh();
    } on Object catch (error) {
      debugPrint('M11 development request save failed: $error');
      if (mounted) {
        ThreadMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save the 3D request. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RequestView>(
      future: _view,
      builder: (context, snapshot) {
        final view = snapshot.data;
        if (view == null) return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Checking experimental 3D availability…'));
        if (view.front == null || view.back == null) return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Experimental 3D generation is unavailable for this garment. Your 2D photos remain available.'));
        final record = view.record;
        final invalid = record != null && !view.valid;
        final status = view.status;
        final canRequest = !invalid && (record == null ||
            (status == record.status &&
             {'FAILED', 'REJECTED', 'READY'}.contains(status)));
        final message = invalid
            ? '3D request needs review: the saved garment or photos changed.'
            : switch (record == null ? null : status ??
                (record.status == 'REQUESTED' ? 'REQUESTED' : 'UNVERIFIED')) {
                null when view.hasPreviousModel => 'An approved 3D preview already exists. A replacement requires a separate request and operator review.',
                null => 'Experimental 3D is available by request. An operator must review the photos and model.',
                'REQUESTED' => '3D request submitted — awaiting operator review.',
                'REVIEW_REQUIRED' => '3D request awaiting input and mask review.',
                'APPROVED' => '3D request approved — awaiting local processing.',
                'OUTPUT_REVIEW_REQUIRED' => '3D model generated — awaiting final review.',
                'READY' => '3D model approved. Open the verified preview above while the local development server is running.',
                'FAILED' => '3D generation failed. Your garment remains saved with its 2D photos.',
                'REJECTED' => '3D request was not approved. Your 2D photos remain available.',
                _ => 'Latest operator status could not be verified. Your request and 2D photos remain saved; refresh when the local review service is available.',
              };
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('3D generation (Experimental)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
            if (view.hasPreviousModel && record != null && status != 'READY')
              const Text('Your previously approved 3D preview remains available.'),
            if (canRequest)
              OutlinedButton.icon(
                onPressed: () => _request(view),
                icon: const Icon(Icons.view_in_ar_outlined),
                label: Text(view.hasPreviousModel
                    ? 'Request replacement 3D (Experimental)'
                    : record == null
                        ? 'Generate 3D (Experimental)'
                        : 'Request 3D again (Experimental)'),
              ),
            TextButton(onPressed: _refresh, child: const Text('Refresh 3D status')),
          ]),
        );
      });
}

class _RequestView {
  const _RequestView(this.front, this.back, this.record, this.valid,
      {this.status, this.hasPreviousModel = false});
  final Uint8List? front;
  final Uint8List? back;
  final M11GenerationRequest? record;
  final bool valid;
  final String? status;
  final bool hasPreviousModel;
}
