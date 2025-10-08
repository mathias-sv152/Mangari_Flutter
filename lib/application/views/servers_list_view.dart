import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista simplificada para mostrar lista de servidores de manga
/// DEPRECADO: Usar ExploreView en su lugar
class ServersListView extends StatefulWidget {
  const ServersListView({super.key});

  @override
  State<ServersListView> createState() => _ServersListViewState();
}

class _ServersListViewState extends State<ServersListView> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DraculaTheme.background,
      body: Center(
        child: Text(
          'Esta vista ha sido reemplazada por ExploreView',
          style: TextStyle(color: DraculaTheme.foreground),
        ),
      ),
    );
  }
}