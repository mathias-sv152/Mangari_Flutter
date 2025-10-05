import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista de Actualizaciones - Muestra las últimas actualizaciones de manga
class UpdatesView extends StatelessWidget {
  const UpdatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualizaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actualizando...'),
                  backgroundColor: DraculaTheme.purple,
                ),
              );
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.update,
              size: 64,
              color: DraculaTheme.cyan,
            ),
            SizedBox(height: 16),
            Text(
              'Actualizaciones Recientes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: DraculaTheme.foreground,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Las últimas actualizaciones de tus manga aparecerán aquí',
              style: TextStyle(
                fontSize: 16,
                color: DraculaTheme.comment,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Chip(
              backgroundColor: DraculaTheme.cyan,
              label: Text(
                'Función en desarrollo',
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
}