import 'package:flutter/material.dart';
import 'package:mangari/application/services/manga_servers_service.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_server_entity.dart';

/// Vista de Exploración - Lista todos los servidores de manga disponibles
class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final MangaServersService _mangaServersService = getIt<MangaServersService>();
  
  List<MangaServerEntity> _mangaServers = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMangaServers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMangaServers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await _mangaServersService.getAllMangaServers();
      
      setState(() {
        _mangaServers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMangaServers(String query) async {
    if (query.isEmpty) {
      _loadMangaServers();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await _mangaServersService.searchMangaServers(query);
      
      setState(() {
        _mangaServers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Servidores'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchMangaServers,
              style: const TextStyle(color: DraculaTheme.foreground),
              decoration: InputDecoration(
                hintText: 'Buscar servidores de manga...',
                hintStyle: const TextStyle(color: DraculaTheme.comment),
                prefixIcon: const Icon(Icons.search, color: DraculaTheme.purple),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: DraculaTheme.comment),
                        onPressed: () {
                          _searchController.clear();
                          _loadMangaServers();
                        },
                      )
                    : null,
                filled: true,
                fillColor: DraculaTheme.currentLine,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: DraculaTheme.purple),
            SizedBox(height: 16),
            Text(
              'Cargando servidores de manga...',
              style: TextStyle(color: DraculaTheme.foreground),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: DraculaTheme.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar servidores',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DraculaTheme.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadMangaServers,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_mangaServers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: DraculaTheme.comment,
            ),
            SizedBox(height: 16),
            Text(
              'No se encontraron servidores',
              style: TextStyle(
                fontSize: 18,
                color: DraculaTheme.comment,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMangaServers,
      color: DraculaTheme.purple,
      backgroundColor: DraculaTheme.currentLine,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mangaServers.length,
        itemBuilder: (context, index) {
          final server = _mangaServers[index];
          return _buildMangaServerCard(server);
        },
      ),
    );
  }

  Widget _buildMangaServerCard(MangaServerEntity server) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DraculaTheme.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.web,
                    color: DraculaTheme.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              server.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: DraculaTheme.foreground,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: server.isActive 
                                  ? DraculaTheme.green.withOpacity(0.2)
                                  : DraculaTheme.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              server.isActive ? 'ACTIVO' : 'INACTIVO',
                              style: TextStyle(
                                color: server.isActive 
                                    ? DraculaTheme.green 
                                    : DraculaTheme.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        server.url,
                        style: const TextStyle(
                          color: DraculaTheme.cyan,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              server.description,
              style: const TextStyle(
                color: DraculaTheme.foreground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.library_books,
                  '${server.mangaCount.toString()} manga',
                  DraculaTheme.orange,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.language,
                  '${server.supportedLanguages.length} idiomas',
                  DraculaTheme.cyan,
                ),
              ],
            ),
            if (server.supportedLanguages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: server.supportedLanguages.take(5).map((lang) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DraculaTheme.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      lang.toUpperCase(),
                      style: const TextStyle(
                        color: DraculaTheme.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Actualizado: ${_formatDate(server.lastUpdated)}',
              style: const TextStyle(
                color: DraculaTheme.comment,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours} h';
    } else {
      return 'hace ${difference.inDays} días';
    }
  }
}