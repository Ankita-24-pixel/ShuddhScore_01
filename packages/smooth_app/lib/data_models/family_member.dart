enum FamilyAgeGroup {
  infant('Infant · under 1'),
  toddler('Toddler · 1 year'),
  child('Child · 2–11'),
  teenager('Teenager · 12–17'),
  adult('Adult · 18–64'),
  olderAdult('Older adult · 65+');

  const FamilyAgeGroup(this.label);
  final String label;
}

class FamilyMember {
  const FamilyMember({required this.id, required this.name, required this.age});

  final String id;
  final String name;
  final int age;

  FamilyAgeGroup get ageGroup {
    if (age < 1) {
      return FamilyAgeGroup.infant;
    }
    if (age < 2) {
      return FamilyAgeGroup.toddler;
    }
    if (age < 12) {
      return FamilyAgeGroup.child;
    }
    if (age < 18) {
      return FamilyAgeGroup.teenager;
    }
    if (age < 65) {
      return FamilyAgeGroup.adult;
    }
    return FamilyAgeGroup.olderAdult;
  }

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'name': name,
    'age': age,
  };

  static FamilyMember? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    final Object? id = value['id'];
    final Object? name = value['name'];
    final Object? age = value['age'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        name.trim().length > 60 ||
        age is! int ||
        age < 0 ||
        age > 120) {
      return null;
    }
    return FamilyMember(id: id, name: name.trim(), age: age);
  }
}
