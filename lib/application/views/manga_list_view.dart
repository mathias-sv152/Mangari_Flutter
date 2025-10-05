import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/application/services/mangadx_service.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/application/components/optimized_manga_grid.dart';
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
  final MangaDxService _mangaService = getIt<MangaDxService>();
  final ScrollController _scrollController = ScrollController();
  
  List<MangaDetailEntity> _mangas = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  String? _errorMessage;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadMangas();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final mangas = await _mangaService.getManga(_currentPage);
      
      setState(() {
        _mangas = mangas;
        _isLoading = false;
        _hasMorePages = mangas.length >= 32; // MangaDx returns 32 per page
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMangas() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newMangas = await _mangaService.getManga(_currentPage + 1);
      
      setState(() {
        _mangas.addAll(newMangas);
        _currentPage++;
        _isLoadingMore = false;
        _hasMorePages = newMangas.length >= 32;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Lista de mangas
          Expanded(child: _buildMangaList()),
        ],
      ),
    );
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
      mangas: _mangas,
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