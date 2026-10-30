import '../../../core/constants/app_constants.dart';

class UserProfileModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  // Role Checks (Fixes profile_screen.dart Ln 103)
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role == AppConstants.roleAdmin;
  bool get isStaff =>
      role.toLowerCase() == 'staff' || role == AppConstants.roleStaff;

  // Convenience alias for displayName
  String get displayName => fullName;

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      fullName: (map['fullName'] ?? map['displayName'] ?? map['name'] ?? '')
          as String,
      role: map['role'] as String? ?? 'Staff',
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : (map['createdAt'] as dynamic).toDate())
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is DateTime
              ? map['updatedAt'] as DateTime
              : (map['updatedAt'] as dynamic).toDate())
          : null,
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'displayName': fullName,
      'role': role,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  UserProfileModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? role,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
