import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/filter_entity.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/application/components/optimized_manga_grid.dart';
import 'package:mangari/application/components/filter_bottom_sheet.dart';
import 'package:mangari/application/views/manga_detail_view.dart';

class MangaListView extends StatefulWidget {
  final ServerEntity server;

  const MangaListView({
    super.key,
    required this.server,
  });

  @override
  State<MangaListView> createState() => _MangaListViewState();
}

class _MangaListViewState extends State<MangaListView> {
  ServersServiceV2? _serversService;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<MangaEntity> _mangas = [];
  List<FilterGroupEntity> _availableFilters = [];
  Map<String, dynamic> _selectedFilters = {};
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  bool _hasFilters = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _searchQuery = '';
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Posponer la inicialización hasta después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
    });
  }

  void _performSearch() async {
    if (_searchQuery.isEmpty) {
      await _loadMangas();
    } else {
      await _searchMangas();
    }
  }

  void _initializeService() async {
    try {
      print('🔍 MangaListView: Esperando un momento antes de inicializar...');
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('🔍 MangaListView: Intentando obtener ServersServiceV2...');
      _serversService = getServersServiceSafely();
      
      if (_serversService != null) {
        print('✅ MangaListView: ServersServiceV2 obtenido correctamente');
        await _loadFilters();
        await _loadMangas();
      } else {
        print('❌ MangaListView: No se pudo obtener ServersServiceV2');
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo inicializar el servicio de servidores';
          });
        }
      }
    } catch (e) {
      print('❌ MangaListView: Error en _initializeService: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inicializando servicios: $e';
        });
      }
    }
  }

  Future<void> _loadFilters() async {
    if (_serversService == null) return;
    
    try {
      final filters = await _serversService!.getFiltersForServer(widget.server.id);
      setState(() {
        _availableFilters = filters;
        _hasFilters = filters.isNotEmpty;
      });
    } catch (e) {
      print('⚠️ Servidor no tiene filtros disponibles: $e');
      setState(() {
        _hasFilters = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreMangas();
      }
    }
  }

  Future<void> _loadMangas() async {
    if (!mounted || _serversService == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      List<MangaEntity> mangas;
      
      // Si hay filtros seleccionados, aplicar filtros
      if (_selectedFilters.isNotEmpty) {
        // Agregar el texto de búsqueda a los filtros si existe
        if (_searchQuery.isNotEmpty) {
          _selectedFilters['searchText'] = _searchQuery;
        }
        mangas = await _serversService!.applyFiltersInServer(
          widget.server.id, 
          _currentPage, 
          _selectedFilters,
        );
      } else if (_searchQuery.isNotEmpty) {
        // Solo búsqueda sin filtros
        mangas = await _serversService!.searchMangaInServer(
          widget.server.id, 
          _searchQuery, 
          page: _currentPage,
        );
      } else {
        // Carga normal sin búsqueda ni filtros
        mangas = await _serversService!.getMangasFromServer(
          widget.server.id, 
          page: _currentPage,
        );
      }
      
      setState(() {
        _mangas = mangas;
        _isLoading = false;
        _hasMorePages = mangas.length >= 20;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMangas() async {
    if (!mounted || _serversService == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      List<MangaEntity> mangas;
      
      // Si hay filtros, combinar búsqueda con filtros
      if (_selectedFilters.isNotEmpty) {
        _selectedFilters['searchText'] = _searchQuery;
        mangas = await _serversService!.applyFiltersInServer(
          widget.server.id, 
          _currentPage, 
          _selectedFilters,
        );
      } else {
        mangas = await _serversService!.searchMangaInServer(
          widget.server.id, 
          _searchQuery, 
          page: _currentPage,
        );
      }
      
      setState(() {
        _mangas = mangas;
        _isLoading = false;
        _hasMorePages = mangas.length >= 20;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMangas() async {
    if (_isLoadingMore || !_hasMorePages || _serversService == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      List<MangaEntity> newMangas;
      
      // Cargar más según el estado actual
      if (_selectedFilters.isNotEmpty || _searchQuery.isNotEmpty) {
        if (_searchQuery.isNotEmpty) {
          _selectedFilters['searchText'] = _searchQuery;
        }
        newMangas = await _serversService!.applyFiltersInServer(
          widget.server.id, 
          _currentPage + 1, 
          _selectedFilters,
        );
      } else {
        newMangas = await _serversService!.getMangasFromServer(
          widget.server.id, 
          page: _currentPage + 1,
        );
      }
      
      setState(() {
        _mangas.addAll(newMangas);
        _currentPage++;
        _isLoadingMore = false;
        _hasMorePages = newMangas.length >= 20;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando más mangas: $e'),
            backgroundColor: DraculaTheme.red,
          ),
        );
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => FilterBottomSheet(
          filterGroups: _availableFilters,
          initialFilters: _selectedFilters,
          onApply: (filters) {
            setState(() {
              _selectedFilters = filters;
            });
            _loadMangas();
          },
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _loadMangas();
  }

  // Método para convertir MangaEntity a MangaDetailEntity
  MangaDetailEntity _convertToMangaDetail(MangaEntity entity) {
    return MangaDetailEntity(
      title: entity.title,
      linkImage: entity.coverImageUrl ?? '',
      link: entity.id,
      bookType: entity.genres.isNotEmpty ? entity.genres.first : '',
      demography: entity.status,
      id: entity.id,
      service: entity.serverSource,
      description: entity.description ?? '',
      genres: [],
      chapters: [],
      author: entity.authors.isNotEmpty ? entity.authors.first : '',
      status: entity.status,
      source: entity.serverSource,
      referer: entity.referer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildMangaList(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasActiveFilters = _selectedFilters.isNotEmpty || _searchQuery.isNotEmpty;
    final appBarHeight = hasActiveFilters ? 104.0 : 56.0;
    
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarHeight),
      child: AppBar(
        scrolledUnderElevation: 0,
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: DraculaTheme.foreground),
              decoration: const InputDecoration(
                hintText: 'Buscar manga (presiona Enter)...',
                hintStyle: TextStyle(color: DraculaTheme.comment),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _performSearch();
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.server.name),
                Text(
                  'Catálogo de Manga',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DraculaTheme.comment,
                  ),
                ),
              ],
            ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _clearSearch();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          // Botón de búsqueda
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _clearSearch();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          // Botón de filtros (solo si el servidor tiene filtros)
          if (_hasFilters)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterBottomSheet,
                ),
                if (_getActiveFiltersCount() > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: DraculaTheme.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_getActiveFiltersCount()}',
                        style: const TextStyle(
                          color: DraculaTheme.background,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
        bottom: hasActiveFilters ? _buildChipsBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildChipsBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildChipsList(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChipsList() {
    List<Widget> chips = [];
    
    // Chip de búsqueda
    if (_searchQuery.isNotEmpty) {
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Chip(
            label: Text('Búsqueda: $_searchQuery'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: _clearSearch,
            backgroundColor: DraculaTheme.purple,
            labelStyle: const TextStyle(color: DraculaTheme.background),
          ),
        ),
      );
    }
    
    // Chips de filtros (excluyendo searchText del conteo)
    final activeFiltersCount = _getActiveFiltersCount();
    if (activeFiltersCount > 0) {
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Chip(
            label: Text('$activeFiltersCount filtro(s) activo(s)'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() {
                _selectedFilters.clear();
              });
              _loadMangas();
            },
            backgroundColor: DraculaTheme.green,
            labelStyle: const TextStyle(color: DraculaTheme.background),
          ),
        ),
      );
    }
    
    return chips;
  }

  /// Obtiene el número de filtros activos excluyendo 'searchText'
  int _getActiveFiltersCount() {
    return _selectedFilters.entries
        .where((entry) => entry.key != 'searchText')
        .length;
  }

  Widget _buildMangaList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: DraculaTheme.purple),
            SizedBox(height: 16),
            Text(
              'Cargando mangas...',
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
                'Error al cargar mangas',
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
                onPressed: _loadMangas,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_mangas.isEmpty) {
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
              'No hay mangas disponibles',
              style: TextStyle(
                fontSize: 18,
                color: DraculaTheme.comment,
              ),
            ),
          ],
        ),
      );
    }

    // Usar el grid optimizado
    return OptimizedMangaGrid(
      mangas: _mangas.map((entity) => _convertToMangaDetail(entity)).toList(),
      scrollController: _scrollController,
      isLoadingMore: _isLoadingMore,
      onMangaTap: (manga) {
        // Navegar a la vista de detalles del manga
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MangaDetailView(
              manga: manga,
              server: widget.server,
            ),
          ),
        );
      },
      onRefresh: _loadMangas,
    );
  }
}