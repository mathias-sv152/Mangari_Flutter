import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';

/// Vista de Más opciones - Configuraciones y opciones adicionales
class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Usuario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: DraculaTheme.purple,
                        child: Icon(
                          Icons.person,
                          color: DraculaTheme.background,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuario Mangari',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: DraculaTheme.foreground,
                            ),
                          ),
                          Text(
                            'usuario@mangari.app',
                            style: TextStyle(
                              color: DraculaTheme.comment,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Manga Leídos', '42'),
                      _buildStatCard('Favoritos', '15'),
                      _buildStatCard('Días Activo', '128'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Opciones de configuración
          _buildSettingsSection(context),
          
          const SizedBox(height: 16),
          
          // Información de la app
          _buildInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: DraculaTheme.purple,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: DraculaTheme.comment,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Configuración',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DraculaTheme.foreground,
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.palette,
            title: 'Tema',
            subtitle: 'Dracula',
            onTap: () => _showThemeDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Idioma',
            subtitle: 'Español',
            onTap: () => _showLanguageDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.download,
            title: 'Descargas',
            subtitle: 'Gestionar descargas',
            onTap: () => _showDownloadsDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notificaciones',
            subtitle: 'Configurar alertas',
            onTap: () => _showNotificationsDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: 'Privacidad',
            subtitle: 'Configuración de privacidad',
            onTap: () => _showPrivacyDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Información',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DraculaTheme.foreground,
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Ayuda y Soporte',
            subtitle: 'Centro de ayuda',
            onTap: () => _showHelpDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.star_outline,
            title: 'Calificar App',
            subtitle: 'Danos tu opinión',
            onTap: () => _showRateDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Reportar Bug',
            subtitle: 'Ayúdanos a mejorar',
            onTap: () => _showBugReportDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: DraculaTheme.purple),
      title: Text(
        title,
        style: const TextStyle(color: DraculaTheme.foreground),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: DraculaTheme.comment),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: DraculaTheme.comment,
      ),
      onTap: onTap,
    );
  }

  void _showThemeDialog(BuildContext context) {
    _showInfoDialog(context, 'Tema', 'El tema Dracula está activo. Próximamente más opciones de tema.');
  }

  void _showLanguageDialog(BuildContext context) {
    _showInfoDialog(context, 'Idioma', 'Idioma actual: Español. Próximamente más idiomas disponibles.');
  }

  void _showDownloadsDialog(BuildContext context) {
    _showInfoDialog(context, 'Descargas', 'Gestión de descargas estará disponible próximamente.');
  }

  void _showNotificationsDialog(BuildContext context) {
    _showInfoDialog(context, 'Notificaciones', 'Configuración de notificaciones disponible próximamente.');
  }

  void _showPrivacyDialog(BuildContext context) {
    _showInfoDialog(context, 'Privacidad', 'Configuración de privacidad estará disponible próximamente.');
  }

  void _showHelpDialog(BuildContext context) {
    _showInfoDialog(context, 'Ayuda', 'Centro de ayuda estará disponible próximamente.');
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mangari',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: DraculaTheme.purple,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.auto_stories,
          color: DraculaTheme.background,
          size: 24,
        ),
      ),
      children: const [
        Text(
          'Mangari es una aplicación para leer manga con arquitectura DDD y tema Dracula.',
          style: TextStyle(color: DraculaTheme.foreground),
        ),
      ],
    );
  }

  void _showRateDialog(BuildContext context) {
    _showInfoDialog(context, 'Calificar', 'Función de calificación estará disponible próximamente.');
  }

  void _showBugReportDialog(BuildContext context) {
    _showInfoDialog(context, 'Reportar Bug', 'Sistema de reporte de bugs estará disponible próximamente.');
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}