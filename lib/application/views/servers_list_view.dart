import 'package:flutter/material.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/application/views/manga_list_view.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';

/// Vista simplificada para mostrar lista de servidores de manga
class ServersListView extends StatefulWidget {
  const ServersListView({super.key});

  @override
  State<ServersListView> createState() => _ServersListViewState();
}

class _ServersListViewState extends State<ServersListView> {
  final ServersServiceV2 _serversService = getIt<ServersServiceV2>();
  
  List<ServerEntity> _servers = [];
  List<ServerEntity> _filteredServers = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await _serversService.getAllServers();
      
      setState(() {
        _servers = servers;
        _filteredServers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterServers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredServers = _servers;
      } else {
        _filteredServers = _servers
            .where((server) => 
                server.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Manga'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda arriba
          _buildSearchBar(),
          
          // Lista de servidores
          Expanded(child: _buildServersList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterServers,
        style: const TextStyle(color: DraculaTheme.foreground),
        decoration: InputDecoration(
          hintText: 'Buscar servidores...',
          hintStyle: const TextStyle(color: DraculaTheme.comment),
          prefixIcon: const Icon(Icons.search, color: DraculaTheme.purple),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: DraculaTheme.comment),
                  onPressed: () {
                    _searchController.clear();
                    _filterServers('');
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
    );
  }

  Widget _buildServersList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: DraculaTheme.purple),
            SizedBox(height: 16),
            Text(
              'Cargando servidores...',
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
                onPressed: _loadServers,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredServers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 64,
              color: DraculaTheme.comment,
            ),
            SizedBox(height: 16),
            Text(
              'No hay servidores disponibles',
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
      onRefresh: _loadServers,
      color: DraculaTheme.purple,
      backgroundColor: DraculaTheme.currentLine,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredServers.length,
        itemBuilder: (context, index) {
          final server = _filteredServers[index];
          return _buildServerCard(server);
        },
      ),
    );
  }

  Widget _buildServerCard(ServerEntity server) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DraculaTheme.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: server.iconUrl.isNotEmpty
                ? Image.network(
                    server.iconUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Icon(
                        Icons.web,
                        color: DraculaTheme.purple,
                        size: 24,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(
                        child: CircularProgressIndicator(
                          color: DraculaTheme.purple,
                          strokeWidth: 2,
                        ),
                      );
                    },
                  )
                : const Icon(
                    Icons.web,
                    color: DraculaTheme.purple,
                    size: 24,
                  ),
          ),
        ),
        title: Text(
          server.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: DraculaTheme.foreground,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Idioma soportado: ${server.language}',
              style: const TextStyle(
                color: DraculaTheme.comment,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              server.baseUrl,
              style: const TextStyle(
                color: DraculaTheme.cyan,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: server.isActive 
                ? DraculaTheme.green.withOpacity(0.2)
                : DraculaTheme.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
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
        isThreeLine: true,
        onTap: () {
          if (server.isActive) {
            _navigateToMangaList(server);
          }
        },
      ),
    );
  }

  void _navigateToMangaList(ServerEntity server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MangaListView(server: server),
      ),
    );
  }
}