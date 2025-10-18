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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fantasy Football AI Assistant',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
