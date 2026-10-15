/// 회원 모델
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
class Member {
  final int id;
  final String username;
  final String? name;
  final String? email;
  final bool isAdmin;

  const Member({
    required this.id,
    required this.username,
    this.name,
    this.email,
    this.isAdmin = false,
  });

  String get displayName => (name != null && name!.isNotEmpty) ? name! : username;

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: (j['id'] as num).toInt(),
        username: j['username'] as String,
        name: j['name'] as String?,
        email: j['email'] as String?,
        isAdmin: (j['is_admin'] as num?)?.toInt() == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'email': email,
        'is_admin': isAdmin ? 1 : 0,
      };
}
