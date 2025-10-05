import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista de Historial - Muestra el historial de manga leído
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _showClearHistoryDialog(context);
            },
            tooltip: 'Limpiar historial',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: DraculaTheme.comment,
            ),
            SizedBox(height: 16),
            Text(
              'Historial de Lectura',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: DraculaTheme.foreground,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí aparecerá tu historial de manga leído',
              style: TextStyle(
                fontSize: 16,
                color: DraculaTheme.comment,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Chip(
              backgroundColor: DraculaTheme.purple,
              label: Text(
                'Próximamente',
                style: TextStyle(
                  color: DraculaTheme.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todo tu historial de lectura?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Historial limpiado'),
                  backgroundColor: DraculaTheme.green,
                ),
              );
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}