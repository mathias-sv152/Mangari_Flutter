import 'package:flutter/material.dart';
import 'package:mangari/application/views/explore_view.dart';
import 'package:mangari/application/views/history_view.dart';
import 'package:mangari/application/views/library_view.dart';
import 'package:mangari/application/views/more_view.dart';
import 'package:mangari/application/views/updates_view.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista principal de la aplicación con navegación inferior
class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ExploreView(), // Vista de exploración actualizada
    const HistoryView(),
    const LibraryView(),
    const UpdatesView(),
    const MoreView(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explorar',
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Historial',
    ),
    NavigationItem(
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books,
      label: 'Biblioteca',
    ),
    NavigationItem(
      icon: Icons.update_outlined,
      activeIcon: Icons.update,
      label: 'Updates',
    ),
    NavigationItem(
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz,
      label: 'Más',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: DraculaTheme.selection,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: DraculaTheme.currentLine,
          selectedItemColor: DraculaTheme.purple,
          unselectedItemColor: DraculaTheme.comment,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          elevation: 8,
          items: _navigationItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _currentIndex == index;
            
            return BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? DraculaTheme.purple.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 24,
                ),
              ),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Clase para representar un elemento de navegación
class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}