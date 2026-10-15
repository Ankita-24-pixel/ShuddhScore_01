import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/family_member.dart';

enum FamilySuitability { suitable, limitOrAvoid, unknown }

class FamilyProductAssessment {
  const FamilyProductAssessment({required this.status, required this.reasons});
  final FamilySuitability status;
  final List<String> reasons;

  String get label => switch (status) {
    FamilySuitability.suitable => 'No age-related concern found',
    FamilySuitability.limitOrAvoid => 'Limit or avoid',
    FamilySuitability.unknown => 'Not enough information',
  };
}

/// A nutrition screening tool, not a prediction of an individual's health.
/// Thresholds: UK front-of-pack guidance. Age advice: CDC and AAP.
class FamilyProductAssessor {
  const FamilyProductAssessor();

  FamilyProductAssessment assess(Product product, FamilyMember member) {
    if (product.productType != null &&
        product.productType != ProductType.food) {
      return const FamilyProductAssessment(
        status: FamilySuitability.unknown,
        reasons: <String>[
          'Age-based nutrition checks only apply to food and drinks.',
        ],
      );
    }
    final List<String> concerns = <String>[];
    final List<String> missing = <String>[];
    final Set<String> categories = (product.categoriesTags ?? <String>[])
        .toSet();
    final Set<String> ingredients = <String>{};
    void collect(List<Ingredient>? values) {
      for (final Ingredient ingredient in values ?? <Ingredient>[]) {
        if (ingredient.id != null) {
          ingredients.add(ingredient.id!.toLowerCase());
        }
        collect(ingredient.ingredients);
      }
    }

    collect(product.ingredients);
    final String ingredientText = (product.ingredientsText ?? '').toLowerCase();
    final bool hasIngredients =
        ingredients.isNotEmpty || ingredientText.trim().isNotEmpty;
    bool containsIngredient(Set<String> tags, String pattern) =>
        ingredients.any(tags.contains) ||
        RegExp(pattern, caseSensitive: false).hasMatch(ingredientText);
    double? value(Nutrient nutrient) {
      final double? number = product.nutriments?.getValue(
        nutrient,
        PerSize.oneHundredGrams,
      );
      return number != null && number.isFinite && number >= 0 ? number : null;
    }

    final double? sugar = value(Nutrient.sugars);
    final double? salt =
        value(Nutrient.salt) ??
        (value(Nutrient.sodium) == null ? null : value(Nutrient.sodium)! * 2.5);
    final double? saturates = value(Nutrient.saturatedFat);
    final bool drink = categories.contains('en:beverages');
    final String basis = drink ? '100 ml' : '100 g';
    final bool minor = member.age < 18;
    final bool honey = containsIngredient(<String>{'en:honey'}, r'\bhoney\b');
    final bool addedSugar =
        (value(Nutrient.addedSugars) ?? 0) > 0 ||
        containsIngredient(
          <String>{
            'en:sugar',
            'en:glucose-syrup',
            'en:fructose-syrup',
            'en:honey',
            'en:sucrose',
          },
          r'\b(sugar|sucrose|glucose syrup|fructose syrup|honey|corn syrup)\b',
        );
    // Do not infer caffeine from a brand or product name.
    final bool caffeine =
        (value(Nutrient.caffeine) ?? 0) > 0 ||
        containsIngredient(<String>{
          'en:caffeine',
          'en:guarana',
        }, r'\b(caffeine|guarana)\b') ||
        categories.contains('en:energy-drinks');
    final bool alcohol =
        (value(Nutrient.alcohol) ?? 0) > 0 ||
        categories.contains('en:alcoholic-beverages');

    if (member.age < 1 && honey) {
      concerns.add(
        'Honey is unsuitable under 12 months because of infant botulism risk.',
      );
    }
    if (member.age < 2 && addedSugar) {
      concerns.add(
        'Children under 2 should avoid added sugars. The label lists an added sugar or sweetener.',
      );
    }
    if (minor && caffeine) {
      concerns.add(
        'Children and teenagers should avoid caffeine and energy drinks. Caffeine can disturb sleep and cause jitteriness or a fast heartbeat.',
      );
    }
    if (alcohol) {
      concerns.add(
        minor
            ? 'Alcohol is unsuitable for children and teenagers.'
            : 'Alcohol carries health risks and is not classified as a healthy food choice at any adult age.',
      );
    }
    if (sugar != null && sugar > (drink ? 11.25 : 22.5)) {
      concerns.add(
        'High total sugar: ${sugar.toStringAsFixed(1)} g per $basis. '
        '${minor ? 'Frequent sugary foods and drinks can contribute to tooth decay and displace nutritious foods during growth.' : 'Frequent excess sugary foods and drinks can contribute to tooth decay and excess energy intake.'} '
        'Total sugar can include naturally occurring sugar; it is not a measure of added sugar alone.',
      );
    }
    if (salt != null && salt > 1.5) {
      concerns.add(
        'High salt: ${salt.toStringAsFixed(2)} g per $basis. '
        '${minor
            ? 'Children need less salt than adults; frequent salty foods can build unhealthy eating habits.'
            : member.age >= 65
            ? 'Keeping salt intake down supports blood-pressure management in older adulthood.'
            : 'A high-salt diet can raise blood pressure over time.'}',
      );
    }
    if (member.age >= 2 && saturates != null && saturates > (drink ? 2.5 : 5)) {
      concerns.add(
        'High saturated fat: ${saturates.toStringAsFixed(1)} g per $basis. '
        'Frequent excess saturated fat can raise LDL cholesterol; compare with a lower-saturated-fat option.',
      );
    }
    if (sugar == null) {
      missing.add('total sugar');
    }
    if (salt == null) {
      missing.add('salt or sodium');
    }
    if (saturates == null) {
      missing.add('saturated fat');
    }
    if (!hasIngredients) {
      missing.add('ingredients');
    }
    if (categories.isEmpty) {
      missing.add('food category');
    }
    if (minor &&
        !caffeine &&
        value(Nutrient.caffeine) == null &&
        categories.any(
          <String>{'en:coffees', 'en:teas', 'en:colas'}.contains,
        )) {
      missing.add('confirmed caffeine content');
    }
    if (member.age < 1) {
      missing.add('exact age in months and feeding stage');
    }
    if (member.age == 1 && !addedSugar && value(Nutrient.addedSugars) == null) {
      missing.add('confirmed added-sugar content for a child under 2');
    }
    if (concerns.isNotEmpty) {
      return FamilyProductAssessment(
        status: FamilySuitability.limitOrAvoid,
        reasons: <String>[
          ...concerns,
          if (missing.isNotEmpty)
            'The assessment is also limited by missing ${missing.join(', ')}.',
        ],
      );
    }
    if (missing.isNotEmpty) {
      return FamilyProductAssessment(
        status: FamilySuitability.unknown,
        reasons: <String>[
          'Missing ${missing.join(', ')}. Check the label before choosing this product.',
          if (member.age < 1)
            'Infant suitability needs age in months, texture and feeding guidance; age in years alone is insufficient.',
        ],
      );
    }
    final String nutritionSummary = member.age < 2
        ? 'Sugar and salt are below the high-label thresholds, with no added sugar identified. Fat needs differ for children under 2; adult saturated-fat screening is not applied.'
        : 'Sugar, salt and saturated fat are below the high-label thresholds.';
    return FamilyProductAssessment(
      status: FamilySuitability.suitable,
      reasons: <String>[
        'No concern was found by the available age and label checks for ${member.ageGroup.label.toLowerCase()}. $nutritionSummary Choose an appropriate portion as part of a varied diet.',
      ],
    );
  }
}
