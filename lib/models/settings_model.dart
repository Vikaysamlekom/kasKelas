/// Model pengaturan (settings) — key-value.
class SettingsModel {
  final int id;
  final String key;
  final String? value;
  final String? description;
  final DateTime updatedAt;

  const SettingsModel({
    required this.id,
    required this.key,
    this.value,
    this.description,
    required this.updatedAt,
  });

  factory SettingsModel.fromMap(Map<String, Object?> map) {
    return SettingsModel(
      id: map['id'] as int,
      key: map['key'] as String,
      value: map['value'] as String?,
      description: map['description'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'key': key,
      'value': value,
      'description': description,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}