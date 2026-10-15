import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_app/data_models/family_member.dart';
import 'package:uuid/uuid.dart';

/// Family details stay on this device and are never sent to product services.
class FamilyProfiles extends ChangeNotifier {
  FamilyProfiles(this._preferences) {
    final String? stored = _preferences.getString(storageKey);
    if (stored == null) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is List) {
        final Set<String> ids = <String>{};
        for (final Object? value in decoded) {
          final FamilyMember? member = FamilyMember.fromJson(value);
          if (member != null && ids.add(member.id)) {
            _members.add(member);
          }
        }
      }
    } on FormatException {
      // A damaged preference must not prevent the app from starting.
    }
  }

  static const String storageKey = 'shuddhscore_family_members_v1';
  final SharedPreferences _preferences;
  final List<FamilyMember> _members = <FamilyMember>[];
  bool _saving = false;

  List<FamilyMember> get members => List<FamilyMember>.unmodifiable(_members);
  bool get saving => _saving;

  Future<void> save({
    required String name,
    required int age,
    String? id,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty ||
        trimmedName.length > 60 ||
        age < 0 ||
        age > 120) {
      throw ArgumentError('Enter a name and an age from 0 to 120.');
    }
    final FamilyMember member = FamilyMember(
      id: id ?? const Uuid().v4(),
      name: trimmedName,
      age: age,
    );
    final List<FamilyMember> updated = members.toList();
    final int index = updated.indexWhere(
      (FamilyMember item) => item.id == member.id,
    );
    if (index < 0) {
      updated.add(member);
    } else {
      updated[index] = member;
    }
    await _persist(updated);
  }

  Future<void> remove(String id) => _persist(
    members.where((FamilyMember member) => member.id != id).toList(),
  );

  Future<void> _persist(List<FamilyMember> updated) async {
    if (_saving) {
      throw StateError('A family update is already being saved.');
    }
    _saving = true;
    notifyListeners();
    try {
      final bool saved = await _preferences.setString(
        storageKey,
        jsonEncode(
          updated.map((FamilyMember member) => member.toJson()).toList(),
        ),
      );
      if (!saved) {
        throw StateError('Could not save family details.');
      }
      _members
        ..clear()
        ..addAll(updated);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
