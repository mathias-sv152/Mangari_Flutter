import 'package:flutter/material.dart';
import 'package:mangari/core/di/service_locator.dart';
import 'package:mangari/application/views/main_navigation_view.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

void main() {
  // Inicializa las dependencias antes de ejecutar la app
  setupDependencies();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mangari',
      debugShowCheckedModeBanner: false,
      theme: DraculaTheme.theme,
      home: const MainNavigationView(),
    );
  }
}
