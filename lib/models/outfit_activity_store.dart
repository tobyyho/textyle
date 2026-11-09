import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'outfit_store.dart';

/// A local calendar date, never a UTC instant. Wire form is YYYY-MM-DD.
@immutable
class CivilDate implements Comparable<CivilDate> {
  CivilDate(this.year, this.month, this.day) {
    final check = DateTime(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      throw FormatException('Invalid local calendar date: $year-$month-$day');
    }
  }

  final int year;
  final int month;
  final int day;

  factory CivilDate.fromLocal(DateTime instant) {
    final local = instant.toLocal();
    return CivilDate(local.year, local.month, local.day);
  }

  factory CivilDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('Expected YYYY-MM-DD local date: $value');
    }
    return CivilDate(int.parse(value.substring(0, 4)),
        int.parse(value.substring(5, 7)), int.parse(value.substring(8, 10)));
  }

  String get wire =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime get localMidnight => DateTime(year, month, day);

  @override
  int compareTo(CivilDate other) => wire.compareTo(other.wire);

  @override
  bool operator ==(Object other) => other is CivilDate && wire == other.wire;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => wire;
}

class OutfitPlan {
  const OutfitPlan({required this.date, required this.outfitId});

  final CivilDate date;
  final String outfitId;

  Map<String, Object?> toJson() => {'date': date.wire, 'outfitId': outfitId};

  factory OutfitPlan.fromJson(Map<String, Object?> json) => OutfitPlan(
      date: CivilDate.parse(json['date'] as String),
      outfitId: json['outfitId'] as String);
}

/// Minimal historical identity snapshot: no invented garment contents.
class OutfitWearEvent {
  const OutfitWearEvent({
    required this.id,
    required this.date,
    required this.outfitId,
    required this.outfitNameSnapshot,
  });

  final String id;
  final CivilDate date;
  final String outfitId;
  final String outfitNameSnapshot;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': date.wire,
        'outfitId': outfitId,
        'outfitNameSnapshot': outfitNameSnapshot,
      };

  factory OutfitWearEvent.fromJson(Map<String, Object?> json) =>
      OutfitWearEvent(
          id: json['id'] as String,
          date: CivilDate.parse(json['date'] as String),
          outfitId: json['outfitId'] as String,
          outfitNameSnapshot: json['outfitNameSnapshot'] as String);
}

abstract interface class OutfitActivityPersistence {
  Future<String?> read();
  Future<void> write(String value);
}

class MemoryOutfitActivityPersistence implements OutfitActivityPersistence {
  MemoryOutfitActivityPersistence([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class OutfitActivityStore extends ChangeNotifier {
  OutfitActivityStore({
    required this.outfits,
    OutfitActivityPersistence? persistence,
    DateTime Function()? clock,
  })  : _persistence = persistence ?? MemoryOutfitActivityPersistence(),
        _clock = clock ?? DateTime.now;

  static const schemaVersion = 1;
  final OutfitStore outfits;
  final OutfitActivityPersistence _persistence;
  final DateTime Function() _clock;
  final List<OutfitPlan> _plans = [];
  final List<OutfitWearEvent> _wears = [];
  Future<void>? _loadFuture;
  String? _loadError;

  String? get loadError => _loadError;

  CivilDate get today => CivilDate.fromLocal(_clock());
  List<OutfitPlan> get plans => List.unmodifiable(
      List<OutfitPlan>.of(_plans)..sort((a, b) => a.date.compareTo(b.date)));
  List<OutfitWearEvent> get wears =>
      List.unmodifiable(List<OutfitWearEvent>.of(_wears)
        ..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date != 0 ? date : a.id.compareTo(b.id);
        }));
  List<OutfitPlan> get upcomingPlans =>
      plans.where((plan) => plan.date.compareTo(today) >= 0).toList();
  OutfitPlan? planOn(CivilDate date) {
    for (final plan in _plans) {
      if (plan.date == date) return plan;
    }
    return null;
  }

  OutfitWearEvent? wearById(String id) {
    for (final event in _wears) {
      if (event.id == id) return event;
    }
    return null;
  }

  int wearCount(String outfitId) =>
      _wears.where((event) => event.outfitId == outfitId).length;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final raw = await _persistence.read();
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      if (decoded['schemaVersion'] != schemaVersion) {
        throw StateError('Unsupported outfit activity schema.');
      }
      final plans = (decoded['plans'] as List)
          .map((item) =>
              OutfitPlan.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
      final wears = (decoded['wears'] as List)
          .map((item) =>
              OutfitWearEvent.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
      if (plans.map((item) => item.date.wire).toSet().length != plans.length ||
          wears.map((item) => item.id).toSet().length != wears.length) {
        throw StateError('Duplicate outfit activity keys.');
      }
      _plans
        ..clear()
        ..addAll(plans);
      _wears
        ..clear()
        ..addAll(wears);
      notifyListeners();
    } on Object {
      _loadError =
          'Outfit activity could not be read. Stored data was preserved; changes are disabled.';
      notifyListeners();
    }
  }

  void _ensureWritable() {
    if (_loadError != null) throw StateError(_loadError!);
  }

  Future<void> _commit(
      List<OutfitPlan> plans, List<OutfitWearEvent> wears) async {
    final committedPlans = List<OutfitPlan>.of(plans);
    final committedWears = List<OutfitWearEvent>.of(wears);
    await _persistence.write(jsonEncode({
      'schemaVersion': schemaVersion,
      'plans': committedPlans.map((item) => item.toJson()).toList(),
      'wears': committedWears.map((item) => item.toJson()).toList(),
    }));
    _plans
      ..clear()
      ..addAll(committedPlans);
    _wears
      ..clear()
      ..addAll(committedWears);
    notifyListeners();
  }

  Future<void> _requireCompleteOutfit(String id) async {
    await outfits.load();
    await outfits.inventory.load();
    final outfit = outfits.findById(id);
    if (outfit == null) throw StateError('Choose a saved outfit.');
    final issue = outfits.validate(outfit.garmentByRole);
    if (issue != null) throw StateError('Repair this outfit first: $issue');
  }

  Future<void> savePlan(CivilDate date, String outfitId,
      {bool replaceExisting = false, CivilDate? previousDate}) async {
    await load();
    _ensureWritable();
    await _requireCompleteOutfit(outfitId);
    if (previousDate != null && planOn(previousDate) == null) {
      throw StateError('The original plan no longer exists.');
    }
    final occupied = planOn(date);
    if (occupied != null &&
        (previousDate == null || occupied.date != previousDate) &&
        !replaceExisting) {
      throw StateError(
          'A plan already exists for ${date.wire}. Confirm replacement.');
    }
    final next = List<OutfitPlan>.of(_plans)
      ..removeWhere((item) => item.date == date || item.date == previousDate)
      ..add(OutfitPlan(date: date, outfitId: outfitId));
    await _commit(next, _wears);
  }

  Future<void> removePlan(CivilDate date) async {
    await load();
    _ensureWritable();
    final next = _plans.where((item) => item.date != date).toList();
    await _commit(next, _wears);
  }

  Future<void> saveWear(CivilDate date, String outfitId,
      {String? eventId}) async {
    await load();
    _ensureWritable();
    if (date.compareTo(today) > 0) {
      throw StateError('Future dates cannot be recorded as already worn.');
    }
    final existing = eventId == null ? null : wearById(eventId);
    if (eventId != null && existing == null) {
      throw StateError('Wear entry no longer exists.');
    }
    if (existing == null || existing.outfitId != outfitId) {
      await _requireCompleteOutfit(outfitId);
    }
    if (_wears.any((item) =>
        item.id != eventId && item.date == date && item.outfitId == outfitId)) {
      throw StateError('This outfit is already recorded for ${date.wire}.');
    }
    final id = eventId ?? 'wear_${date.wire}_$outfitId';
    final next = _wears.where((item) => item.id != eventId).toList()
      ..add(OutfitWearEvent(
          id: id,
          date: date,
          outfitId: outfitId,
          outfitNameSnapshot: existing?.outfitId == outfitId
              ? existing!.outfitNameSnapshot
              : outfits.findById(outfitId)!.name));
    await _commit(_plans, next);
  }

  Future<void> removeWear(String eventId) async {
    await load();
    _ensureWritable();
    final next = _wears.where((item) => item.id != eventId).toList();
    await _commit(_plans, next);
  }
}
