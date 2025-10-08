import 'package:flutter/material.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/views/manga_list_view.dart';

/// Vista de Exploración - Lista todos los servidores de manga disponibles
class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  ServersServiceV2? _serversService;
  
  List<ServerEntity> _servers = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  void _initializeService() async {
    try {
      print('🔍 ExploreView: Esperando un momento antes de inicializar...');
      // Pequeño delay para asegurar que todas las dependencias estén listas
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('🔍 ExploreView: Intentando obtener ServersServiceV2...');
      print('🔍 ExploreView: GetIt instance hashCode: ${getIt.hashCode}');
      
      // Intentar ambos métodos
      print('🔍 ExploreView: Método 1 - Helper seguro...');
      _serversService = getServersServiceSafely();
      
      if (_serversService == null) {
        print('🔍 ExploreView: Método 2 - Acceso directo...');
        try {
          _serversService = getIt.get<ServersServiceV2>();
          print('✅ ExploreView: Método directo funcionó!');
        } catch (e) {
          print('❌ ExploreView: Método directo falló: $e');
          
          print('🔍 ExploreView: Método 3 - isRegistered + get...');
          if (getIt.isRegistered<ServersServiceV2>()) {
            print('✓ ExploreView: Está registrado, intentando get...');
            _serversService = getIt.get<ServersServiceV2>();
            print('✅ ExploreView: Método 3 funcionó!');
          } else {
            print('❌ ExploreView: No está registrado en método 3');
          }
        }
      }
      
      if (_serversService != null) {
        print('✅ ExploreView: ServersServiceV2 obtenido correctamente');
        await _loadMangaServers();
      } else {
        print('❌ ExploreView: No se pudo obtener ServersServiceV2 con ningún método');
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo inicializar el servicio de servidores';
          });
        }
      }
    } catch (e) {
      print('❌ ExploreView: Error en _initializeService: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inicializando servicios: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMangaServers() async {
    if (!mounted || _serversService == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servers = await _serversService!.getAllServers();
      
      if (!mounted) return;
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMangaServers(String query) async {
    if (_serversService == null) return;
    
    if (query.isEmpty) {
      _loadMangaServers();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Por ahora simplemente filtrar de la lista cargada
      final allServers = await _serversService!.getAllServers();
      final filteredServers = allServers.where((server) => 
        server.name.toLowerCase().contains(query.toLowerCase())
      ).toList();
      
      setState(() {
        _servers = filteredServers;
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

    if (_servers.isEmpty) {
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
        itemCount: _servers.length,
        itemBuilder: (context, index) {
          final server = _servers[index];
          return _buildMangaServerCard(server);
        },
      ),
    );
  }

  Widget _buildMangaServerCard(ServerEntity server) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navegar al listado de mangas de este servidor
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MangaListView(server: server),
            ),
          );
        },
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
                          server.baseUrl,
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
                'Servidor de manga ${server.serviceName ?? server.name}',
                style: const TextStyle(
                  color: DraculaTheme.foreground,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.language,
                    server.language,
                    DraculaTheme.cyan,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.source,
                    server.serviceName ?? 'Servicio',
                    DraculaTheme.orange,
                  ),
                ],
              ),
            ],
          ),
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

}