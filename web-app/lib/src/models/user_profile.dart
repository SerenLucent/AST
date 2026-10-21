class UserProfile {
  const UserProfile({
    required this.loginId,
    required this.nickname,
    this.role = 'member',
  });

  final String loginId;
  final String? nickname;
  final String role;
}
