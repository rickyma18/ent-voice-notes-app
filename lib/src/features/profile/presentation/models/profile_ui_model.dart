/// UI model for displaying profile information.
/// This decouples the UI from domain/data layer entities.
class ProfileUiModel {
  const ProfileUiModel({
    required this.name,
    required this.email,
    this.imageUrl,
  });

  /// User's display name
  final String name;

  /// User's email address
  final String email;

  /// Optional profile image URL
  final String? imageUrl;

  /// Generates initials from the name (max 2 characters)
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) {
      final len = parts.first.length.clamp(0, 2);
      return parts.first.substring(0, len).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
