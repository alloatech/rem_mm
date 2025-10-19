import 'package:flutter/material.dart';
import 'package:rem_mm/core/theme/elevated_containers.dart';
import 'package:rem_mm/core/widgets/sleeper_avatar.dart';
import 'package:rem_mm/features/leagues/domain/roster.dart';

class RosterCard extends StatelessWidget {
  final Roster roster;
  final VoidCallback? onTap;

  const RosterCard({super.key, required this.roster, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedCard(
      onTap: onTap,
      child: Row(
        children: [
          // Avatar with consistent handling - prefer team avatar
          SleeperAvatar(
            avatarUrl: roster.avatarUrl,
            fallbackText: roster.ownerDisplayName ?? roster.shortName,
            radius: 24,
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 16),

          // Team info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roster.shortName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: roster.isCurrentUser ? FontWeight.bold : FontWeight.w600,
                    color: roster.isCurrentUser ? theme.colorScheme.primary : null,
                  ),
                ),
                const SizedBox(height: 4),
                // Owner name with small avatar
                Row(
                  children: [
                    // Small user avatar (always uses user avatar, not team avatar)
                    SleeperAvatar(
                      avatarId: roster.avatarId,
                      fallbackText: roster.ownerDisplayName ?? 'U',
                      radius: 10,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        roster.ownerDisplayName ?? 'Unknown Owner',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Team stats and badge
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${roster.playerIds.length} players',
                style: theme.textTheme.bodySmall,
              ),
              if (roster.isCurrentUser) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'YOUR TEAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
