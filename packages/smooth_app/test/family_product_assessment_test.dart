import 'package:flutter_test/flutter_test.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/family_member.dart';
import 'package:smooth_app/services/family_product_assessment.dart';

FamilyMember person(int age) =>
    FamilyMember(id: 'person', name: 'Member', age: age);

Product food({double sugar = 2, double salt = 0.2, double saturated = 1}) =>
    Product(
      barcode: '1234567890123',
      categoriesTags: <String>['en:foods'],
      ingredientsText: 'Oats, water',
      nutriments: Nutriments.empty()
        ..setValue(Nutrient.sugars, PerSize.oneHundredGrams, sugar)
        ..setValue(Nutrient.salt, PerSize.oneHundredGrams, salt)
        ..setValue(Nutrient.saturatedFat, PerSize.oneHundredGrams, saturated),
    );

void main() {
  const FamilyProductAssessor assessor = FamilyProductAssessor();

  test('all age-group boundaries', () {
    final Map<int, FamilyAgeGroup> ages = <int, FamilyAgeGroup>{
      0: FamilyAgeGroup.infant,
      1: FamilyAgeGroup.toddler,
      2: FamilyAgeGroup.child,
      11: FamilyAgeGroup.child,
      12: FamilyAgeGroup.teenager,
      17: FamilyAgeGroup.teenager,
      18: FamilyAgeGroup.adult,
      64: FamilyAgeGroup.adult,
      65: FamilyAgeGroup.olderAdult,
      120: FamilyAgeGroup.olderAdult,
    };
    ages.forEach(
      (int age, FamilyAgeGroup group) => expect(person(age).ageGroup, group),
    );
  });

  test('complete low-concern label is green for child and adult', () {
    for (final int age in <int>[2, 12, 18, 65]) {
      expect(
        assessor.assess(food(), person(age)).status,
        FamilySuitability.suitable,
      );
    }
  });

  test('same product has different results for toddler and adult', () {
    final Product product = food()..ingredientsText = 'Oats, sugar';
    expect(
      assessor.assess(product, person(1)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor.assess(product, person(30)).status,
      FamilySuitability.suitable,
    );
  });

  test('infant never green using completed years only and honey is red', () {
    expect(
      assessor.assess(food(), person(0)).status,
      FamilySuitability.unknown,
    );
    final Product product = food()
      ..ingredients = <Ingredient>[
        Ingredient(
          id: 'en:compound',
          ingredients: <Ingredient>[Ingredient(id: 'en:honey')],
        ),
      ];
    expect(
      assessor.assess(product, person(0)).reasons.join(),
      contains('botulism'),
    );
    expect(
      assessor.assess(product, person(0)).status,
      FamilySuitability.limitOrAvoid,
    );
  });

  test('missing and invalid nutrition never treated as zero', () {
    for (final double? invalid in <double?>[
      null,
      -1,
      double.nan,
      double.infinity,
    ]) {
      final Product product = food()
        ..nutriments!.setValue(
          Nutrient.sugars,
          PerSize.oneHundredGrams,
          invalid,
        );
      expect(
        assessor.assess(product, person(30)).status,
        FamilySuitability.unknown,
      );
    }
    expect(
      assessor.assess(Product(), person(30)).status,
      FamilySuitability.unknown,
    );
    expect(
      assessor.assess(food()..ingredientsText = null, person(30)).status,
      FamilySuitability.unknown,
    );
    expect(
      assessor.assess(food()..categoriesTags = null, person(30)).status,
      FamilySuitability.unknown,
    );
  });

  test('red evidence is retained even when other data is missing', () {
    final Product product = Product(ingredientsText: 'Caffeine');
    expect(
      assessor.assess(product, person(12)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor.assess(product, person(12)).reasons.join(),
      contains('missing'),
    );
  });

  test('food thresholds and drink thresholds use correct boundaries', () {
    expect(
      assessor
          .assess(food(sugar: 22.5, salt: 1.5, saturated: 5), person(30))
          .status,
      FamilySuitability.suitable,
    );
    expect(
      assessor.assess(food(sugar: 22.6), person(30)).status,
      FamilySuitability.limitOrAvoid,
    );
    final Product drink = food(sugar: 11.3)
      ..categoriesTags = <String>['en:beverages'];
    expect(
      assessor.assess(drink, person(30)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor.assess(drink, person(30)).reasons.join(),
      contains('100 ml'),
    );
  });

  test('sodium is converted from grams to salt', () {
    final Product product = food()
      ..nutriments!.setValue(Nutrient.salt, PerSize.oneHundredGrams, null)
      ..nutriments!.setValue(Nutrient.sodium, PerSize.oneHundredGrams, 0.7);
    final FamilyProductAssessment result = assessor.assess(product, person(70));
    expect(result.status, FamilySuitability.limitOrAvoid);
    expect(result.reasons.join(), contains('1.75 g'));
    expect(result.reasons.join(), contains('older adulthood'));
  });

  test('caffeine concerns depend on age; brand names do not trigger them', () {
    final Product product = food()
      ..ingredientsText = 'Water, caffeine'
      ..categoriesTags = <String>['en:beverages'];
    expect(
      assessor.assess(product, person(17)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor.assess(product, person(18)).status,
      FamilySuitability.suitable,
    );
    final Product named = food()..productName = 'Coffee caffeine brand';
    expect(
      assessor.assess(named, person(10)).status,
      FamilySuitability.suitable,
    );
    final Product decaf = food()
      ..ingredientsText = 'Decaffeinated coffee'
      ..categoriesTags = <String>['en:beverages', 'en:coffees'];
    expect(
      assessor.assess(decaf, person(10)).status,
      FamilySuitability.unknown,
    );
  });

  test(
    'natural sugar not reported as added sugar and toddlers need confirmation',
    () {
      final Product product = food(sugar: 4)..ingredientsText = 'Milk';
      expect(
        assessor.assess(product, person(1)).status,
        FamilySuitability.unknown,
      );
      product.nutriments!.setValue(
        Nutrient.addedSugars,
        PerSize.oneHundredGrams,
        0,
      );
      expect(
        assessor.assess(product, person(1)).status,
        FamilySuitability.suitable,
      );
    },
  );

  test('toddler fat needs do not use adult saturated-fat rules', () {
    final Product product = food(saturated: 6);
    product.nutriments!.setValue(
      Nutrient.addedSugars,
      PerSize.oneHundredGrams,
      0,
    );
    final FamilyProductAssessment result = assessor.assess(product, person(1));
    expect(result.status, FamilySuitability.suitable);
    expect(
      result.reasons.join(),
      contains('adult saturated-fat screening is not applied'),
    );
    expect(
      assessor.assess(product, person(30)).status,
      FamilySuitability.limitOrAvoid,
    );
  });

  test('alcohol cannot be green and non-food products cannot be green', () {
    final Product alcoholic = food()
      ..categoriesTags = <String>['en:alcoholic-beverages'];
    expect(
      assessor.assess(alcoholic, person(15)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor.assess(alcoholic, person(30)).status,
      FamilySuitability.limitOrAvoid,
    );
    expect(
      assessor
          .assess(food()..productType = ProductType.beauty, person(30))
          .status,
      FamilySuitability.unknown,
    );
  });
}
