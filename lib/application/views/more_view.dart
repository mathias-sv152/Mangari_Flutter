import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/infrastructure/database/database_service.dart';

/// Vista de Más opciones - Configuraciones y opciones adicionales
class MoreView extends StatefulWidget {
  const MoreView({super.key});

  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isCleaningCache = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
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
                            style: TextStyle(color: DraculaTheme.comment),
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
          style: const TextStyle(fontSize: 12, color: DraculaTheme.comment),
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
          _buildSettingsTile(
            icon: Icons.cleaning_services,
            title: 'Limpiar Caché',
            subtitle: 'Eliminar progreso no guardado',
            onTap: () => _showCleanCacheDialog(context),
            trailing:
                _isCleaningCache
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DraculaTheme.purple,
                      ),
                    )
                    : null,
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
    Widget? trailing,
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
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, color: DraculaTheme.comment),
      onTap: onTap,
    );
  }

  void _showThemeDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Tema',
      'El tema Dracula está activo. Próximamente más opciones de tema.',
    );
  }

  void _showLanguageDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Idioma',
      'Idioma actual: Español. Próximamente más idiomas disponibles.',
    );
  }

  void _showDownloadsDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Descargas',
      'Gestión de descargas estará disponible próximamente.',
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Notificaciones',
      'Configuración de notificaciones disponible próximamente.',
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Privacidad',
      'Configuración de privacidad estará disponible próximamente.',
    );
  }

  void _showHelpDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Ayuda',
      'Centro de ayuda estará disponible próximamente.',
    );
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
    _showInfoDialog(
      context,
      'Calificar',
      'Función de calificación estará disponible próximamente.',
    );
  }

  void _showBugReportDialog(BuildContext context) {
    _showInfoDialog(
      context,
      'Reportar Bug',
      'Sistema de reporte de bugs estará disponible próximamente.',
    );
  }

  Future<void> _showCleanCacheDialog(BuildContext context) async {
    // Primero obtener estadísticas de la BD
    final stats = await _databaseService.getDatabaseStats();
    final orphanedCount = stats['orphanedProgress'] as int;

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: DraculaTheme.background,
            title: const Row(
              children: [
                Icon(Icons.cleaning_services, color: DraculaTheme.orange),
                SizedBox(width: 12),
                Text(
                  'Limpiar Caché',
                  style: TextStyle(color: DraculaTheme.foreground),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acción eliminará:',
                  style: TextStyle(
                    color: DraculaTheme.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCleanupItem(
                  '• Progreso de lectura de mangas NO guardados',
                  orphanedCount > 0,
                ),
                _buildCleanupItem(
                  '• Progreso de lectura antiguo (>90 días)',
                  true,
                ),
                _buildCleanupItem(
                  '• Capítulos descargados de mangas NO guardados',
                  true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DraculaTheme.selection,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DraculaTheme.comment.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: DraculaTheme.cyan,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          orphanedCount > 0
                              ? 'Se encontraron $orphanedCount registros huérfanos'
                              : 'Tu base de datos está limpia',
                          style: const TextStyle(
                            color: DraculaTheme.foreground,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Los mangas guardados en tu biblioteca NO se verán afectados.',
                  style: TextStyle(
                    color: DraculaTheme.comment,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: DraculaTheme.comment),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _performCacheCleanup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.orange,
                  foregroundColor: DraculaTheme.background,
                ),
                child: const Text('Limpiar'),
              ),
            ],
          ),
    );
  }

  Widget _buildCleanupItem(String text, bool willClean) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            willClean ? Icons.check_circle : Icons.circle_outlined,
            color: willClean ? DraculaTheme.green : DraculaTheme.comment,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    willClean ? DraculaTheme.foreground : DraculaTheme.comment,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performCacheCleanup() async {
    if (_isCleaningCache) return;

    setState(() => _isCleaningCache = true);

    try {
      // Mostrar SnackBar de inicio
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DraculaTheme.background,
                  ),
                ),
                SizedBox(width: 12),
                Text('Limpiando caché...'),
              ],
            ),
            backgroundColor: DraculaTheme.purple,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Realizar limpieza
      final results = await _databaseService.performFullCacheCleanup();
      final totalCleaned = results['total'] ?? 0;

      if (mounted) {
        // Mostrar resultado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: DraculaTheme.background,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Caché limpiado exitosamente',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Registros eliminados: $totalCleaned\n'
                  '• Progreso huérfano: ${results['orphanedProgress']}\n'
                  '• Progreso antiguo: ${results['oldProgress']}\n'
                  '• Capítulos huérfanos: ${results['orphanedChapters']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: DraculaTheme.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error limpiando caché: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al limpiar caché: $e'),
            backgroundColor: DraculaTheme.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCleaningCache = false);
      }
    }
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
