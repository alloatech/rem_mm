import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/auth/presentation/providers/auth_providers.dart';
import 'package:rem_mm/features/leagues/presentation/providers/leagues_providers.dart';

class SleeperLinkPage extends ConsumerStatefulWidget {
  const SleeperLinkPage({super.key});

  @override
  ConsumerState<SleeperLinkPage> createState() => _SleeperLinkPageState();
}

class _SleeperLinkPageState extends ConsumerState<SleeperLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _linkSleeperAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final identifier = _identifierController.text.trim();

      // Pass the identifier to both parameters - the Edge Function will figure out which it is
      final result = await authService.registerWithSleeper(
        sleeperUserId: identifier,
        sleeperUsername: identifier,
      );

      print('DEBUG: Sleeper registration result: $result');
      _showMessage('successfully linked to sleeper account!');

      // Refresh auth status by invalidating the providers that check Sleeper linking
      print('DEBUG: Invalidating providers...');
      ref.invalidate(isLinkedToSleeperProvider);
      ref.invalidate(currentSleeperUserIdProvider);
      ref.invalidate(authStatusProvider);

      // Also invalidate leagues to trigger re-fetch
      ref.invalidate(userLeaguesProvider);

      // Force a re-check
      print('DEBUG: Checking auth status after invalidation...');
      final newStatus = ref.read(authStatusProvider);
      print('DEBUG: New auth status: $newStatus');

      // Navigate back to previous screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage('failed to link sleeper account: ${error.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('link sleeper account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Column(
                  children: [
                    Icon(Icons.link, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'connect your sleeper account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'link your sleeper account to access your leagues and get personalized fantasy advice',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sleeper Username or ID Field
                        TextFormField(
                          controller: _identifierController,
                          decoration: const InputDecoration(
                            labelText: 'sleeper username or user ID',
                            prefixIcon: Icon(Icons.person_outlined),
                            helperText: 'enter your sleeper username (case-sensitive)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'please enter your sleeper username or user ID';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          onFieldSubmitted: (_) {
                            // Submit form when Enter is pressed
                            if (!_isLoading) _linkSleeperAccount();
                          },
                        ),

                        const SizedBox(height: 24),

                        // Link Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _linkSleeperAccount,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'link account',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Help Text
                Card(
                  color: theme.colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'how to find your sleeper username',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. open the sleeper app or website\n'
                          '2. tap your profile icon\n'
                          '3. your username is displayed at the top\n'
                          '4. username is case-sensitive - enter it exactly as shown',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
