import '../models/clothing_item.dart';

/// Deterministic, local, metadata-only recommendation heuristic (v1).
/// Scores rank suggestions; they are not probabilities or fashion guarantees.
class OutfitSuggestion {
  const OutfitSuggestion({
    required this.garmentByRole,
    required this.score,
    required this.reasons,
    required this.warnings,
  });

  final Map<LayerRole, String> garmentByRole;
  final int score;
  final List<String> reasons;
  final List<String> warnings;

  String get identity {
    final ids = garmentByRole.values.toList()..sort();
    return ids.join('|');
  }
}

class OutfitRecommendationResult {
  const OutfitRecommendationResult({
    required this.suggestions,
    required this.message,
    required this.evaluatedCandidates,
  });

  final List<OutfitSuggestion> suggestions;
  final String? message;
  final int evaluatedCandidates;
}

class OutfitRecommendationService {
  static const version = 'local-rules-v1';
  static const maxPerRole = 32;
  static const maxSuggestions = 5;
  static const maxCandidates = 3200;

  const OutfitRecommendationService();

  OutfitRecommendationResult recommend(Iterable<ClothingItem> wardrobe,
      {Season? season}) {
    final byRole = <LayerRole, List<ClothingItem>>{};
    var ownedCount = 0;
    for (final item in wardrobe) {
      if (item.id.trim().isEmpty) continue;
      // Textyle's startup catalogue fixtures are not proof of ownership.
      if (item.source.type == GarmentSourceType.catalogue) continue;
      ownedCount++;
      final role = item.attributes.layerRole;
      if (!const [
        LayerRole.top,
        LayerRole.bottom,
        LayerRole.onePiece,
        LayerRole.outerwear
      ].contains(role)) continue;
      byRole.putIfAbsent(role, () => []).add(item);
    }

    List<ClothingItem> pool(LayerRole role) {
      final items = List<ClothingItem>.of(byRole[role] ?? const []);
      items.sort((a, b) {
        if (season != null) {
          final c =
              _seasonPriority(b, season).compareTo(_seasonPriority(a, season));
          if (c != 0) return c;
        }
        return a.id.compareTo(b.id);
      });
      return items.take(maxPerRole).toList();
    }

    final tops = pool(LayerRole.top);
    final bottoms = pool(LayerRole.bottom);
    final dresses = pool(LayerRole.onePiece);
    final coats = pool(LayerRole.outerwear);
    final candidates = <OutfitSuggestion>[];
    final seen = <String>{};

    void add(Map<LayerRole, ClothingItem> parts) {
      if (candidates.length >= maxCandidates) return;
      final ids = parts.values.map((item) => item.id).toList();
      if (ids.toSet().length != ids.length) return;
      if (season != null &&
          parts.values.any((item) =>
              item.attributes.seasons.isNotEmpty &&
              !item.attributes.seasons.contains(season))) return;
      final roles = parts.map((role, item) => MapEntry(role, item.id));
      final reasons = <String>[];
      final warnings = <String>[];
      var score = 100; // All candidates have a complete primary structure.
      final knownCategories = parts.values
          .where(
              (item) => item.classification.category != GarmentCategory.unknown)
          .length;
      score += knownCategories * 3;
      if (knownCategories == parts.length) {
        reasons.add('The saved garment categories are specified.');
      }
      if (season != null) {
        final matches = parts.values
            .where((item) => item.attributes.seasons.contains(season))
            .length;
        score += matches * 12;
        if (matches == parts.length) {
          reasons.add('All pieces are tagged for ${season.name}.');
        } else if (matches > 0) {
          reasons.add('$matches piece${matches == 1 ? '' : 's'} '
              '${matches == 1 ? 'is' : 'are'} tagged for ${season.name}.');
        }
        if (matches < parts.length) {
          warnings.add('Some garment seasons are not specified.');
        }
      }
      final primary = parts[LayerRole.top] ?? parts[LayerRole.onePiece]!;
      final companion = parts[LayerRole.bottom];
      if (companion != null) {
        final pair = _colourPair(primary, companion);
        score += pair.$1;
        if (pair.$2 != null) reasons.add(pair.$2!);
      }
      if (parts.containsKey(LayerRole.outerwear)) {
        score += 2;
        reasons.add('Includes an optional outerwear layer.');
      }
      if (parts.values.any((item) => _colour(item) == null)) {
        warnings.add('Some garment colours are not specified or recognized.');
      }
      final suggestion = OutfitSuggestion(
          garmentByRole: roles,
          score: score,
          reasons: reasons.isEmpty
              ? const ['A complete outfit from your wardrobe.']
              : reasons,
          warnings: warnings);
      if (seen.add(suggestion.identity)) candidates.add(suggestion);
    }

    // One-piece candidates and bounded top/bottom pairs. Only the two best
    // outerwear choices are considered per base outfit; no full wardrobe
    // Cartesian product is generated.
    for (final dress in dresses) {
      add({LayerRole.onePiece: dress});
      for (final coat in coats.take(2)) {
        add({LayerRole.onePiece: dress, LayerRole.outerwear: coat});
      }
    }
    for (final top in tops) {
      for (final bottom in bottoms) {
        add({LayerRole.top: top, LayerRole.bottom: bottom});
        for (final coat in coats.take(2)) {
          add({
            LayerRole.top: top,
            LayerRole.bottom: bottom,
            LayerRole.outerwear: coat
          });
        }
      }
    }
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.identity.compareTo(b.identity);
    });

    // Greedy variety: rank by score while penalizing repeated primary items.
    final selected = <OutfitSuggestion>[];
    final usedPrimary = <String, int>{};
    final usedBottom = <String, int>{};
    final remaining = List<OutfitSuggestion>.of(candidates);
    while (selected.length < maxSuggestions && remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final aRank = _diverseRank(a, usedPrimary, usedBottom);
        final bRank = _diverseRank(b, usedPrimary, usedBottom);
        final c = bRank.compareTo(aRank);
        return c != 0 ? c : a.identity.compareTo(b.identity);
      });
      final choice = remaining.removeAt(0);
      selected.add(choice);
      final primary = choice.garmentByRole[LayerRole.top] ??
          choice.garmentByRole[LayerRole.onePiece]!;
      usedPrimary[primary] = (usedPrimary[primary] ?? 0) + 1;
      final bottom = choice.garmentByRole[LayerRole.bottom];
      if (bottom != null) usedBottom[bottom] = (usedBottom[bottom] ?? 0) + 1;
    }

    String? message;
    if (selected.isEmpty) {
      if (ownedCount == 0) {
        message = 'Add garments to your wardrobe to get outfit suggestions.';
      } else if (season != null &&
          (tops.isNotEmpty && bottoms.isNotEmpty || dresses.isNotEmpty)) {
        message = 'No complete outfits are available for ${season.name}. '
            'Try another season or update garment details.';
      } else if (tops.isNotEmpty && bottoms.isEmpty && dresses.isEmpty) {
        message = 'Add a bottom to create an outfit with your top.';
      } else if (bottoms.isNotEmpty && tops.isEmpty && dresses.isEmpty) {
        message = 'Add a top to create an outfit with your bottom.';
      } else {
        message = 'Add a top and bottom, or a one-piece garment. '
            'Check unknown outfit roles in garment details.';
      }
    }
    return OutfitRecommendationResult(
        suggestions: selected,
        message: message,
        evaluatedCandidates: candidates.length);
  }

  int _seasonPriority(ClothingItem item, Season season) =>
      item.attributes.seasons.contains(season)
          ? 2
          : item.attributes.seasons.isEmpty
              ? 1
              : 0;

  int _diverseRank(
      OutfitSuggestion s, Map<String, int> primary, Map<String, int> bottoms) {
    final id =
        s.garmentByRole[LayerRole.top] ?? s.garmentByRole[LayerRole.onePiece]!;
    final bottom = s.garmentByRole[LayerRole.bottom];
    return s.score -
        15 * (primary[id] ?? 0) -
        (bottom == null ? 0 : 7 * (bottoms[bottom] ?? 0));
  }

  String? _colour(ClothingItem item) {
    final raw = (item.attributes.primaryColor ?? item.colorLabel)
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    const known = {
      'black',
      'white',
      'grey',
      'gray',
      'blue',
      'red',
      'green',
      'yellow',
      'orange',
      'pink',
      'purple',
      'brown',
      'beige_or_cream'
    };
    if (!known.contains(raw)) return null;
    return raw == 'gray' ? 'grey' : raw;
  }

  (int, String?) _colourPair(ClothingItem a, ClothingItem b) {
    final first = _colour(a);
    final second = _colour(b);
    if (first == null || second == null) return (0, null);
    const neutral = {'black', 'white', 'grey', 'brown', 'beige_or_cream'};
    if (first == second) return (8, 'The pieces share the same saved colour.');
    if (neutral.contains(first) && neutral.contains(second)) {
      return (6, 'Both pieces have neutral saved colours.');
    }
    if (neutral.contains(first) || neutral.contains(second)) {
      return (7, 'A neutral-coloured piece pairs with another colour.');
    }
    const related = [
      {'blue', 'purple'},
      {'red', 'pink'},
      {'yellow', 'orange'}
    ];
    if (related.any((pair) => pair.contains(first) && pair.contains(second))) {
      return (4, 'The saved colours are closely related.');
    }
    return (0, null);
  }
}
