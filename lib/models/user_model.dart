/// Model pengguna aplikasi (login/system operator).
class UserModel {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String? nip;
  final String role;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    this.nip,
    this.role = 'bendahara',
    this.isActive = true,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, Object?> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String,
      nip: map['nip'] as String?,
      role: (map['role'] as String?) ?? 'bendahara',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      lastLogin: map['last_login'] != null
          ? DateTime.tryParse(map['last_login'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'nip': nip,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}