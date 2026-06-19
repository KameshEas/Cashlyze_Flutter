/// User model for Cashlyze app
class UserModel {

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.updatedAt,
    this.preferences,
  });

  /// Create UserModel from Firebase User
  factory UserModel.fromFirebaseUser(
    final String uid,
    final String email, {
    final String? displayName,
    final String? photoURL,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      createdAt: DateTime.now(),
    );
  }

  /// Create UserModel from Firestore document
  factory UserModel.fromRTDB(final String id, final Map<String, dynamic> data) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      createdAt: DateTime.fromMillisecondsSinceEpoch((data['created_at_ms'] as num).toInt()),
      updatedAt: data['updated_at_ms'] != null
          ? DateTime.fromMillisecondsSinceEpoch((data['updated_at_ms'] as num).toInt())
          : null,
      preferences: data['preferences'] as Map<String, dynamic>?,
    );
  }
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? preferences;

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toRTDB() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'created_at_ms': createdAt.millisecondsSinceEpoch,
      'updated_at_ms': updatedAt?.millisecondsSinceEpoch,
      'preferences': preferences,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    final String? uid,
    final String? email,
    final String? displayName,
    final String? photoURL,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoURL == photoURL;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        photoURL.hashCode;
  }
}
