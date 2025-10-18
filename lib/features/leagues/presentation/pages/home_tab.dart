import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/leagues/domain/league.dart';
import 'package:rem_mm/features/leagues/presentation/providers/leagues_providers.dart';
import 'package:rem_mm/features/profile/presentation/providers/profile_providers.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasLeaguesAsync = ref.watch(hasLeaguesProvider);
    final userLeaguesAsync = ref.watch(userLeaguesListProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'fantasy leagues',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'manage your fantasy football teams',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Leagues content
              Expanded(
                child: hasLeaguesAsync.when(
                  data: (hasLeagues) {
                    if (!hasLeagues) {
                      return _buildNoLeaguesView(context, theme, ref);
                    }

                    return userLeaguesAsync.when(
                      data: (leagues) => _buildLeaguesView(context, theme, leagues, ref),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          _buildErrorView(context, theme, error, ref),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildErrorView(context, theme, error, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLeaguesView(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_football,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'no leagues found',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'sync your sleeper leagues to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildSyncButton(context, theme, ref),
          const SizedBox(height: 16),
          _buildDebugSection(context, theme, ref),
        ],
      ),
    );
  }

  Widget _buildLeaguesView(
    BuildContext context,
    ThemeData theme,
    List<LeagueListItem> leagues,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        // Sync button
        Align(
          alignment: Alignment.centerRight,
          child: _buildSyncButton(context, theme, ref, isCompact: true),
        ),
        const SizedBox(height: 16),

        // Leagues list
        Expanded(
          child: ListView.separated(
            itemCount: leagues.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final league = leagues[index];
              return _buildLeagueCard(context, theme, league, ref);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueCard(
    BuildContext context,
    ThemeData theme,
    LeagueListItem league,
    WidgetRef ref,
  ) {
    final lastSynced = league.lastSynced;
    final timeSince = DateTime.now().difference(lastSynced);
    String syncText;

    if (timeSince.inMinutes < 1) {
      syncText = 'just now';
    } else if (timeSince.inHours < 1) {
      syncText = '${timeSince.inMinutes}m ago';
    } else if (timeSince.inDays < 1) {
      syncText = '${timeSince.inHours}h ago';
    } else {
      syncText = '${timeSince.inDays}d ago';
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to league details
          _showLeagueDetails(context, league);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      league.leagueName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      league.leagueType.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.group,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${league.totalRosters} teams',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    league.season.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'synced $syncText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncButton(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref, {
    bool isCompact = false,
  }) {
    final sleeperUserId = ref.watch(currentSleeperUserIdProvider);

    if (sleeperUserId == null) {
      return const SizedBox.shrink();
    }

    final syncAsync = ref.watch(leagueSyncProvider(sleeperUserId));

    return syncAsync.when(
      data: (_) => ElevatedButton.icon(
        onPressed: () {
          ref.invalidate(leagueSyncProvider(sleeperUserId));
        },
        icon: Icon(Icons.sync, size: isCompact ? 16 : 20),
        label: Text(
          'sync leagues',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isCompact ? 12 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 16,
            vertical: isCompact ? 8 : 12,
          ),
        ),
      ),
      loading: () => ElevatedButton.icon(
        onPressed: null,
        icon: SizedBox(
          width: isCompact ? 16 : 20,
          height: isCompact ? 16 : 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        label: Text(
          'syncing...',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isCompact ? 12 : 14),
        ),
      ),
      error: (error, stack) => ElevatedButton.icon(
        onPressed: () {
          ref.invalidate(leagueSyncProvider(sleeperUserId));
        },
        icon: Icon(Icons.refresh, size: isCompact ? 16 : 20),
        label: Text(
          'retry sync',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isCompact ? 12 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    ThemeData theme,
    Object error,
    WidgetRef ref,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'error loading leagues',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(hasLeaguesProvider);
              ref.invalidate(userLeaguesListProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('retry', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugSection(BuildContext context, ThemeData theme, WidgetRef ref) {
    final debugAsync = ref.watch(debugLeaguesProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'debug info',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            debugAsync.when(
              data: (debug) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'status: ${debug['success'] == true ? 'ok' : 'error'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (debug['success'] == true) ...[
                    Text(
                      'leagues found: ${debug['leagues_count']}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (debug['leagues'] != null && (debug['leagues'] as List).isNotEmpty)
                      Text(
                        'names: ${(debug['leagues'] as List).join(', ')}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ] else ...[
                    Text(
                      'error: ${debug['error']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              loading: () =>
                  Text('loading debug info...', style: theme.textTheme.bodySmall),
              error: (error, stack) => Text(
                'debug error: $error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.invalidate(debugLeaguesProvider);
                ref.invalidate(hasLeaguesProvider);
                ref.invalidate(userLeaguesListProvider);
              },
              child: Text(
                'refresh debug',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeagueDetails(BuildContext context, LeagueListItem league) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          league.leagueName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('season: ${league.season}'),
            Text('type: ${league.leagueType}'),
            Text('teams: ${league.totalRosters}'),
            Text('last synced: ${league.lastSynced}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }
}
