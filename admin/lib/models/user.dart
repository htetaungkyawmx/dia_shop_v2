class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.locale,
    required this.balance,
    this.phone,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String status;
  final String locale;
  final int balance;
  final String? phone;
  final String? photoUrl;
  final DateTime? createdAt;

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
        status: json['status'] as String? ?? 'ACTIVE',
        locale: json['locale'] as String? ?? 'my',
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        phone: json['phone'] as String?,
        photoUrl: json['photoUrl'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
      );

  AppUser copyWith(
      {int? balance,
      String? displayName,
      String? phone,
      String? photoUrl,
      String? locale}) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role,
      status: status,
      locale: locale ?? this.locale,
      balance: balance ?? this.balance,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
