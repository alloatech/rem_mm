import 'package:flutter/material.dart';

/// Consistent avatar widget for Sleeper users
/// Handles loading, error states, and fallbacks consistently across the app
/// Supports both avatar IDs and direct URLs
class SleeperAvatar extends StatelessWidget {
  final String? avatarId;
  final String? avatarUrl; // Direct URL (e.g., from metadata.avatar)
  final String? fallbackText;
  final double radius;
  final Color? backgroundColor;
  final Color? fallbackTextColor;

  const SleeperAvatar({
    super.key,
    this.avatarId,
    this.avatarUrl,
    this.fallbackText,
    this.radius = 24,
    this.backgroundColor,
    this.fallbackTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the avatar URL to use
    // Priority: direct URL > constructed URL from avatar ID > fallback
    String? finalAvatarUrl;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      finalAvatarUrl = avatarUrl;
    } else if (avatarId != null && avatarId!.isNotEmpty) {
      finalAvatarUrl = 'https://sleepercdn.com/avatars/thumbs/$avatarId';
    }

    // If no avatar URL available, show fallback immediately
    if (finalAvatarUrl == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? theme.colorScheme.primary,
        child: Center(child: _buildFallback(theme)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? theme.colorScheme.surfaceVariant,
      child: ClipOval(
        child: Image.network(
          finalAvatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Show fallback when Sleeper avatar fails to load
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: backgroundColor ?? theme.colorScheme.primary,
              child: Center(child: _buildFallback(theme)),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Text(
        fallbackText!.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: fallbackTextColor ?? Colors.white,
        ),
      );
    }

    return Icon(
      Icons.person,
      size: radius * 1.2,
      color: fallbackTextColor ?? theme.colorScheme.onSurfaceVariant,
    );
  }
}
