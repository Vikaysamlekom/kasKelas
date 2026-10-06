/// Model profil sekolah (school_profile).
class SchoolProfileModel {
  final int? id;
  final String schoolName;
  final String? npsn;
  final String? address;
  final String? phone;
  final String? email;
  final String? headmaster;
  final String? treasurer;
  final String? logoPath;
  final DateTime updatedAt;

  const SchoolProfileModel({
    this.id,
    required this.schoolName,
    this.npsn,
    this.address,
    this.phone,
    this.email,
    this.headmaster,
    this.treasurer,
    this.logoPath,
    required this.updatedAt,
  });

  factory SchoolProfileModel.fromMap(Map<String, Object?> map) {
    return SchoolProfileModel(
      id: map['id'] as int?,
      schoolName: map['school_name'] as String,
      npsn: map['npsn'] as String?,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      headmaster: map['headmaster'] as String?,
      treasurer: map['treasurer'] as String?,
      logoPath: map['logo_path'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'school_name': schoolName,
      'npsn': npsn,
      'address': address,
      'phone': phone,
      'email': email,
      'headmaster': headmaster,
      'treasurer': treasurer,
      'logo_path': logoPath,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}