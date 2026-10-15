import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_app/data_models/family_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'add edit delete persist across reload without changing identity',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final FamilyProfiles profiles = FamilyProfiles(preferences);
      await profiles.save(name: '  Anaya  ', age: 10);
      final String id = profiles.members.single.id;
      expect(FamilyProfiles(preferences).members.single.name, 'Anaya');
      await profiles.save(id: id, name: 'Anaya', age: 11);
      expect(profiles.members.single.id, id);
      expect(FamilyProfiles(preferences).members.single.age, 11);
      await profiles.remove(id);
      expect(FamilyProfiles(preferences).members, isEmpty);
    },
  );

  test(
    'invalid ages and names are rejected without replacing saved data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final FamilyProfiles profiles = FamilyProfiles(
        await SharedPreferences.getInstance(),
      );
      await profiles.save(name: 'Valid', age: 30);
      for (final int age in <int>[-1, 121]) {
        await expectLater(
          profiles.save(name: 'Name', age: age),
          throwsArgumentError,
        );
      }
      await expectLater(profiles.save(name: ' ', age: 30), throwsArgumentError);
      expect(profiles.members.single.name, 'Valid');
    },
  );

  test(
    'corrupt preference and invalid entries do not break app startup',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        FamilyProfiles.storageKey: '{broken',
      });
      expect(
        FamilyProfiles(await SharedPreferences.getInstance()).members,
        isEmpty,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        FamilyProfiles.storageKey: jsonEncode(<Object>[
          <String, Object>{'id': 'one', 'name': 'Valid', 'age': 25},
          <String, Object>{'id': 'one', 'name': 'Duplicate', 'age': 26},
          <String, Object>{'id': 'two', 'name': 'Invalid', 'age': -1},
        ]),
      });
      expect(
        FamilyProfiles(await SharedPreferences.getInstance()).members.length,
        1,
      );
    },
  );
}
