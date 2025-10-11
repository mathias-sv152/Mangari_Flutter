/// Tags y filtros disponibles para Hitomi
/// Sistema de ordenamiento basado en archivos .nozomi
final List<Map<String, String>> hitomiOrderTags = [
  // Ordenamiento por fecha
  {"name": "Fecha Añadida", "value": "date_added", "type": "orderBy"},
  {"name": "Fecha Publicada", "value": "date_published", "type": "orderBy"},
  
  // Ordenamiento por popularidad
  {"name": "Popular: Hoy", "value": "popular_today", "type": "orderBy"},
  {"name": "Popular: Semana", "value": "popular_week", "type": "orderBy"},
  {"name": "Popular: Mes", "value": "popular_month", "type": "orderBy"},
  {"name": "Popular: Año", "value": "popular_year", "type": "orderBy"},
  
  // Dirección de ordenamiento
  {"name": "Aleatorio", "value": "random", "type": "orderDir"},
];
