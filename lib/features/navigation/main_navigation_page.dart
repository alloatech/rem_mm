import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/admin/presentation/pages/admin_tab.dart';
import 'package:rem_mm/features/fantasy_advice/presentation/pages/ai_assistant_tab.dart';
import 'package:rem_mm/features/leagues/presentation/pages/home_tab.dart';
import 'package:rem_mm/features/profile/presentation/widgets/user_avatar.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Simple navigation without blocking on admin check to prevent infinite loading
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
      const BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'AI'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'admin',
      ),
    ];

    final List<Widget> pages = [
      const HomeTab(),
      const AIAssistantTab(),
      const AdminTab(), // Always include admin tab - it will handle access internally
    ];

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Fantasy Football AI Assistant',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        // Use themed app bar background (avoid transparent which reveals dark system background)
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 4,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16.0), child: UserAvatar()),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: navItems,
      ),
    );
  }
}
