import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista de Biblioteca - Muestra la colección personal de manga
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Biblioteca'),
          bottom: const TabBar(
            labelColor: DraculaTheme.purple,
            unselectedLabelColor: DraculaTheme.comment,
            indicatorColor: DraculaTheme.purple,
            tabs: [
              Tab(text: 'Favoritos', icon: Icon(Icons.favorite)),
              Tab(text: 'Leyendo', icon: Icon(Icons.auto_stories)),
              Tab(text: 'Completados', icon: Icon(Icons.check_circle)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavoritesTab(),
            _ReadingTab(),
            _CompletedTab(),
          ],
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline,
            size: 64,
            color: DraculaTheme.pink,
          ),
          SizedBox(height: 16),
          Text(
            'Manga Favoritos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DraculaTheme.foreground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tus manga favoritos aparecerán aquí',
            style: TextStyle(color: DraculaTheme.comment),
          ),
        ],
      ),
    );
  }
}

class _ReadingTab extends StatelessWidget {
  const _ReadingTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: DraculaTheme.orange,
          ),
          SizedBox(height: 16),
          Text(
            'Leyendo Actualmente',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DraculaTheme.foreground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Los manga que estás leyendo aparecerán aquí',
            style: TextStyle(color: DraculaTheme.comment),
          ),
        ],
      ),
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: DraculaTheme.green,
          ),
          SizedBox(height: 16),
          Text(
            'Manga Completados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DraculaTheme.foreground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Los manga que has terminado aparecerán aquí',
            style: TextStyle(color: DraculaTheme.comment),
          ),
        ],
      ),
    );
  }
}