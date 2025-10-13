import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista de Biblioteca - Muestra la colección personal de manga
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Predeterminado'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addNewTab() async {
    final String? tabName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _NewTabDialog(existingNames: _tabs);
      },
    );

    if (tabName != null && tabName.isNotEmpty && mounted) {
      // Verificar que no exista un tab con el mismo nombre
      if (_tabs.contains(tabName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ya existe una lista con el nombre "$tabName"'),
              backgroundColor: DraculaTheme.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('Agregando nuevo tab: $tabName');
      setState(() {
        _tabs.add(tabName);
        final oldController = _tabController;
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: _tabs.length - 1,
        );
        oldController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

class _LibraryTab extends StatelessWidget {
  final String name;

  const _LibraryTab({required this.name});

  @override
  Widget build(BuildContext context) {
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
            name,
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
        ],
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
