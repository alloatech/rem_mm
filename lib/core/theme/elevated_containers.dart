import 'package:flutter/material.dart';

const double _kCardRadius = 16.0;

/// Elevated header container with shadow and perspective
/// Perfect for section headers on black backgrounds
class ElevatedHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? elevation;
  final double borderWidth;
  final double radius;

  const ElevatedHeader({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderWidth = 1.0,
    this.radius = _kCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0.5,
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}

/// Elevated card with strong shadow and perspective
class ElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double borderWidth;
  final double radius;

  const ElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.borderWidth = 1.0,
    this.radius = _kCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            theme.cardColor, // Use theme card color for better contrast
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Primary shadow - more subtle like phlux
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          // Accent glow
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0.5,
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: borderWidth,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding ?? const EdgeInsets.all(10), child: child),
        ),
      ),
    );
  }
}
