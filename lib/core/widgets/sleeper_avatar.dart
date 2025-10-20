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
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? theme.colorScheme.primary,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        ),
        child: Center(child: _buildFallback(theme)),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? theme.colorScheme.surfaceVariant,
        child: ClipOval(
          child: Image.network(
            finalAvatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
              // Show fallback when Sleeper avatar fails to load
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: backgroundColor ?? theme.colorScheme.primary,
                child: Center(child: _buildFallback(theme)),
              );
            },
            loadingBuilder:
                (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  if (loadingProgress.expectedTotalBytes != null) {
                    final value =
                        loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!;
                    return SizedBox(
                      width: radius * 2,
                      height: radius * 2,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                          value: value.clamp(0.0, 1.0),
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    width: radius * 2,
                    height: radius * 2,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Text(
        fallbackText!.substring(0, 1).toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
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
