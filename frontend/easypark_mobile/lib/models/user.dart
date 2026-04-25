class User {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phone;
  final DateTime birthDate;
  final bool isActive;
  final List<String> roles;
  final double coins;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    this.phone,
    required this.birthDate,
    required this.isActive,
    required this.roles,
    required this.coins,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      birthDate: DateTime.parse(json['birthDate'] as String),
      isActive: json['isActive'] as bool,
      roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
      coins: (json['coins'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'phone': phone,
      'birthDate': birthDate.toIso8601String(),
      'isActive': isActive,
      'roles': roles,
      'coins': coins,
    };
  }
}
