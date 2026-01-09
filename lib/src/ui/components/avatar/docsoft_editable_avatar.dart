import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

/// Docsoft Editable Avatar
/// A circular avatar with initials/image and an edit badge.
///
/// Features:
/// - Displays initials when no image is provided
/// - Shows network image when imageUrl is provided
/// - Camera badge in bottom-right corner for edit action
/// - White border and subtle shadow
class DocsoftEditableAvatar extends StatelessWidget {
  const DocsoftEditableAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 110.0,
    this.onTap,
  });

  /// Initials to display when no image is available (max 2 chars recommended)
  final String initials;

  /// Optional image URL for profile photo
  final String? imageUrl;

  /// Avatar diameter (default: 110.0)
  final double size;

  /// Callback when avatar is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.32;
    final badgeIconSize = size * 0.18;
    final borderWidth = size * 0.036;
    final initialsSize = size * 0.33;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DocsoftColors.primary,
              border: Border.all(
                color: DocsoftColors.surface,
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildInitials(initialsSize);
                      },
                    )
                  : _buildInitials(initialsSize),
            ),
          ),

          // Camera badge
          Positioned(
            bottom: size * 0.036,
            right: size * 0.036,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: DocsoftColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: badgeIconSize,
                color: DocsoftColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(double fontSize) {
    return Center(
      child: Text(
        initials,
        style: DocsoftTextStyles.headline.copyWith(
          color: DocsoftColors.onPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
