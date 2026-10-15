import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_app/cards/product_cards/smooth_product_card_found.dart';
import 'package:smooth_app/cards/product_cards/smooth_product_image.dart';
import 'package:smooth_app/data_models/family_profiles.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/l10n/app_localizations.dart';
import 'package:smooth_app/pages/family/family_members_page.dart';
import 'package:smooth_app/pages/family/family_product_card.dart';
import 'package:smooth_app/themes/smooth_theme_colors.dart';
import 'package:smooth_app/themes/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FamilyProfiles profiles;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    profiles = FamilyProfiles(await SharedPreferences.getInstance());
  });

  Widget app(Widget child) => ChangeNotifierProvider<FamilyProfiles>.value(
    value: profiles,
    child: MaterialApp(home: child),
  );

  testWidgets('form validates, saves and edits a member', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(const FamilyMembersPage()));
    await tester.tap(find.text('Add family member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter an age from 0 to 120'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Riya');
    await tester.enterText(find.byType(TextFormField).at(1), '8');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(profiles.members.single.name, 'Riya');
    expect(find.text('Riya'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Riya'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(profiles.members.single.age, 9);
    expect(profiles.members.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same product renders green and red members with reasons', (
    WidgetTester tester,
  ) async {
    await profiles.save(name: 'Toddler', age: 1);
    await profiles.save(name: 'Parent', age: 30);
    final Product product = Product(
      barcode: '123',
      ingredientsText: 'Oats, sugar',
      categoriesTags: <String>['en:foods'],
      nutriments: Nutriments.empty()
        ..setValue(Nutrient.sugars, PerSize.oneHundredGrams, 2)
        ..setValue(Nutrient.salt, PerSize.oneHundredGrams, 0.1)
        ..setValue(Nutrient.saturatedFat, PerSize.oneHundredGrams, 1),
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: FamilyProductCard(product: product),
          ),
        ),
      ),
    );
    expect(find.text('Limit or avoid'), findsOneWidget);
    expect(find.text('No age-related concern found'), findsOneWidget);
    final Icon red = tester.widget<Icon>(
      find.byIcon(Icons.warning_amber_rounded),
    );
    final Icon green = tester.widget<Icon>(
      find.byIcon(Icons.check_circle_outline),
    );
    expect(red.color, const Color(0xFFB3261E));
    expect(green.color, const Color(0xFF176B36));
    await tester.tap(find.text('Toddler · 1 year').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Children under 2 should avoid added sugars'),
      findsOneWidget,
    );
    expect(find.text('Explain simply with AI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact results handle narrow screens and long names', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await profiles.save(
      name: 'A very long family member name that fits the allowed limit',
      age: 20,
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: FamilyProductChips(product: Product()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacing a search product updates facts and family colours', (
    WidgetTester tester,
  ) async {
    await profiles.save(name: 'Adult', age: 48);
    Product item(String barcode, double sugar) => Product(
      barcode: barcode,
      productName: 'Product $barcode',
      ingredientsText: 'Oats, water',
      categoriesTags: <String>['en:foods'],
      nutriments: Nutriments.empty()
        ..setValue(Nutrient.sugars, PerSize.oneHundredGrams, sugar)
        ..setValue(Nutrient.salt, PerSize.oneHundredGrams, 0.1)
        ..setValue(Nutrient.saturatedFat, PerSize.oneHundredGrams, 1),
    );
    await tester.pumpWidget(
      app(Scaffold(body: FamilyProductChips(product: item('111', 46)))),
    );
    expect(find.textContaining('Sugars 46.00 g'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await tester.pumpWidget(
      app(Scaffold(body: FamilyProductChips(product: item('222', 2)))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sugars 46.00 g'), findsNothing);
    expect(find.textContaining('Sugars 2.00 g'), findsOneWidget);
    expect(find.text('Product: 222'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets(
    'reused product card exposes the current product to child widgets',
    (WidgetTester tester) async {
      await profiles.save(name: 'Adult', age: 48);
      final UserPreferences preferences =
          await UserPreferences.getUserPreferences();
      final ThemeProvider themeProvider = ThemeProvider(preferences);
      Widget card(Product product) =>
          ChangeNotifierProvider<UserPreferences>.value(
            value: preferences,
            child: ChangeNotifierProvider<ThemeProvider>.value(
              value: themeProvider,
              child: ChangeNotifierProvider<FamilyProfiles>.value(
                value: profiles,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: const <Locale>[Locale('en')],
                  theme: ThemeData(
                    extensions: <ThemeExtension<dynamic>>[
                      SmoothColorsThemeExtension.defaultValues(true),
                    ],
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: SmoothProductCardItemFound(
                        product: product,
                        heroTag: 'test',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      final Product first = Product(barcode: '111', productName: 'First')
        ..productType = ProductType.food
        ..productNameInLanguages = <OpenFoodFactsLanguage, String>{
          OpenFoodFactsLanguage.ENGLISH: 'First',
        };
      final Product second = Product(barcode: '222', productName: 'Second')
        ..productType = ProductType.food
        ..productNameInLanguages = <OpenFoodFactsLanguage, String>{
          OpenFoodFactsLanguage.ENGLISH: 'Second',
        };
      await tester.pumpWidget(card(first));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(ProductPicture)).read<Product>().barcode,
        '111',
      );
      expect(find.text('N/A'), findsNothing);
      await tester.pumpWidget(card(second));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(ProductPicture)).read<Product>().barcode,
        '222',
      );
      expect(
        tester
            .widget<ProductPicture>(find.byType(ProductPicture))
            .product!
            .barcode,
        '222',
      );
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
