import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/application/services/library_service.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/domain/entities/saved_manga_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/views/manga_detail_view.dart';
import 'package:mangari/application/components/optimized_manga_grid.dart';
import 'package:mangari/core/di/service_locator.dart';

/// Vista de Biblioteca - Muestra la colección personal de manga
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> _tabs = ['Predeterminado'];
  LibraryService? _libraryService;
  ServersServiceV2? _serversService;
  bool _isLoadingCategories = true;
  StreamSubscription? _libraryChangesSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeServices();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Opcional: Agregar lógica adicional al cambiar de tab
      setState(() {}); // Forzar rebuild para actualizar el contenido
    }
  }

  Future<void> _initializeServices() async {
    try {
      _libraryService = getLibraryServiceSafely();
      _serversService = getServersServiceSafely();

      if (_libraryService != null) {
        await _loadCategories();
        _listenToLibraryChanges();
      }
    } catch (e) {
      print('❌ Error inicializando servicios de biblioteca: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  void _listenToLibraryChanges() {
    if (_libraryService == null) return;

    _libraryChangesSubscription = _libraryService!.libraryChanges.listen((
      event,
    ) {
      // Recargar categorías cuando se agregan o eliminan
      if (event.type == LibraryChangeType.categoryAdded ||
          event.type == LibraryChangeType.categoryDeleted) {
        _loadCategories();
      }
    });
  }

  Future<void> _loadCategories() async {
    if (_libraryService == null) return;

    try {
      final categories = await _libraryService!.getCategories();

      if (mounted && categories.isNotEmpty) {
        setState(() {
          _tabs = categories;
          final oldController = _tabController;
          final oldIndex = oldController.index;
          _tabController = TabController(
            length: _tabs.length,
            vsync: this,
            initialIndex: oldIndex < _tabs.length ? oldIndex : 0,
          );
          _tabController.addListener(_onTabChanged);
          oldController.dispose();
        });
      }
    } catch (e) {
      print('❌ Error cargando categorías: $e');
    }
  }

  @override
  void dispose() {
    _libraryChangesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addNewTab() async {
    if (_libraryService == null) return;

    final String? tabName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _NewTabDialog(existingNames: _tabs);
      },
    );

    if (tabName != null && tabName.isNotEmpty && mounted) {
      try {
        await _libraryService!.createCategory(tabName);
        await _loadCategories();

        // Navegar al nuevo tab
        final newIndex = _tabs.indexOf(tabName);
        if (newIndex >= 0) {
          _tabController.animateTo(newIndex);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Categoría "$tabName" creada'),
              backgroundColor: DraculaTheme.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        print('❌ Error creando categoría: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Ya existe una categoría con ese nombre'),
              backgroundColor: DraculaTheme.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
      return const Scaffold(
        backgroundColor: DraculaTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: DraculaTheme.purple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DraculaTheme.background,
      appBar: AppBar(
        backgroundColor: DraculaTheme.currentLine,
        title: const Text(
          'Mi Biblioteca',
          style: TextStyle(
            color: DraculaTheme.foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: DraculaTheme.purple),
            tooltip: 'Agregar lista',
            onPressed: _addNewTab,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 0),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: DraculaTheme.purple,
                unselectedLabelColor: DraculaTheme.comment,
                indicatorColor: DraculaTheme.purple,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _tabs.map((tabName) => Tab(text: tabName)).toList(),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tabName) => _LibraryTab(name: tabName)).toList(),
      ),
    );
  }
}

class _LibraryTab extends StatefulWidget {
  final String name;

  const _LibraryTab({required this.name});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab>
    with AutomaticKeepAliveClientMixin {
  LibraryService? _libraryService;
  ServersServiceV2? _serversService;
  List<SavedMangaEntity> _mangas = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _libraryChangesSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _libraryChangesSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    _libraryService = getLibraryServiceSafely();
    _serversService = getServersServiceSafely();

    await _loadMangas();
    _listenToLibraryChanges();
  }

  void _listenToLibraryChanges() {
    if (_libraryService == null) return;

    _libraryChangesSubscription = _libraryService!.libraryChanges.listen(
      (event) {
        // Solo recargar si el cambio afecta a esta categoría
        bool shouldReload = false;

        switch (event.type) {
          case LibraryChangeType.mangaAdded:
            shouldReload = event.category == widget.name;
            break;
          case LibraryChangeType.mangaDeleted:
            shouldReload = event.category == widget.name;
            break;
          case LibraryChangeType.mangaMoved:
            // Recargar si el manga salió de esta categoría o llegó a ella
            shouldReload =
                event.category == widget.name ||
                event.oldCategory == widget.name;
            break;
          default:
            break;
        }

        if (shouldReload && mounted) {
          _loadMangas();
        }
      },
      onError: (error) {
        print('❌ LibraryTab(${widget.name}): Error en stream: $error');
      },
    );
  }

  Future<void> _loadMangas() async {
    if (_libraryService == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final mangas = await _libraryService!.getSavedMangasByCategory(
        widget.name,
      );

      if (mounted) {
        setState(() {
          _mangas = mangas;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando mangas de ${widget.name}: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToMangaDetail(SavedMangaEntity savedManga) async {
    if (_serversService == null) return;

    try {
      // Obtener el servidor
      final servers = await _serversService!.getAllServers();
      final server = servers.firstWhere(
        (s) => s.id == savedManga.serverId,
        orElse:
            () => ServerEntity(
              id: savedManga.serverId,
              name: savedManga.serverName,
              baseUrl: '',
              iconUrl: '',
              language: 'es',
              isActive: true,
            ),
      );

      // Convertir SavedMangaEntity a MangaDetailEntity
      final mangaDetail = _libraryService!.savedMangaToDetailEntity(savedManga);

      if (!mounted) return;

      // Navegar a la vista de detalle
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MangaDetailView(manga: mangaDetail, server: server),
        ),
      );

      // Recargar después de volver (siempre, por si cambió de categoría o se eliminó)
      await _loadMangas();

      // También necesitamos recargar las categorías del padre por si se creó una nueva
      if (mounted && result == true) {
        // Buscar el padre LibraryView y recargar sus categorías
        final libraryState =
            context.findAncestorStateOfType<_LibraryViewState>();
        libraryState?._loadCategories();
      }
    } catch (e) {
      print('❌ Error navegando a detalle: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necesario para AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: DraculaTheme.purple),
      );
    }

    if (_mangas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 64,
              color: DraculaTheme.purple,
            ),
            const SizedBox(height: 16),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: DraculaTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus manga aparecerán aquí',
              style: TextStyle(color: DraculaTheme.comment),
            ),
            const SizedBox(height: 16),
            const Text(
              'Guarda tus mangas favoritos desde la vista de detalle',
              textAlign: TextAlign.center,
              style: TextStyle(color: DraculaTheme.comment, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMangas,
      color: DraculaTheme.purple,
      backgroundColor: DraculaTheme.currentLine,
      child: OptimizedMangaGrid(
        scrollController: _scrollController,
        isLoadingMore: false,
        onRefresh: _loadMangas,
        mangas:
            _mangas.map((savedManga) {
              return _libraryService!.savedMangaToDetailEntity(savedManga);
            }).toList(),
        onMangaTap: (manga) {
          // Encontrar el SavedMangaEntity correspondiente
          final savedManga = _mangas.firstWhere(
            (m) => m.mangaId == manga.id && m.serverId == manga.service,
          );
          _navigateToMangaDetail(savedManga);
        },
      ),
    );
  }
}

class _NewTabDialog extends StatefulWidget {
  final List<String> existingNames;

  const _NewTabDialog({required this.existingNames});

  @override
  State<_NewTabDialog> createState() => _NewTabDialogState();
}

class _NewTabDialogState extends State<_NewTabDialog> {
  late final TextEditingController _nameController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_validateName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateName);
    _nameController.dispose();
    super.dispose();
  }

  void _validateName() {
    final name = _nameController.text.trim();
    setState(() {
      if (name.isEmpty) {
        _errorText = null;
      } else if (widget.existingNames.contains(name)) {
        _errorText = 'Ya existe una lista con este nombre';
      } else {
        _errorText = null;
      }
    });
  }

  void _submitName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && !widget.existingNames.contains(name)) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;
    final isEmpty = _nameController.text.trim().isEmpty;

    return AlertDialog(
      backgroundColor: DraculaTheme.background,
      title: const Text(
        'Nueva Lista',
        style: TextStyle(color: DraculaTheme.foreground),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(color: DraculaTheme.foreground),
        decoration: InputDecoration(
          hintText: 'Nombre de la lista',
          hintStyle: const TextStyle(color: DraculaTheme.comment),
          errorText: _errorText,
          errorStyle: const TextStyle(color: DraculaTheme.red),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: hasError ? DraculaTheme.red : DraculaTheme.selection,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: hasError ? DraculaTheme.red : DraculaTheme.purple,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: DraculaTheme.red),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: DraculaTheme.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onSubmitted: (value) => _submitName(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: DraculaTheme.comment),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                hasError || isEmpty
                    ? DraculaTheme.comment
                    : DraculaTheme.purple,
            foregroundColor: DraculaTheme.background,
          ),
          onPressed: hasError || isEmpty ? null : _submitName,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
