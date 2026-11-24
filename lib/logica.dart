// ============================================================
//  TaskFlow Wearable — logica.dart  (Prácticas 11 y 12)
// ============================================================

/// Deja solo las tareas del estado elegido.
/// Práctica 12: compara sin distinguir mayúsculas ("Pendiente" == "pendiente").
List<dynamic> filtrarPorEstado(List<dynamic> todas, String filtro) {
  final f = filtro.toLowerCase();
  return todas.where((t) => t['estado']?.toString().toLowerCase() == f).toList();
}

/// Muestra la hora como HH:mm.
/// Práctica 12: ya no truena si la hora viene con menos de 5 caracteres.
String formatearHora(dynamic hora) {
  final h = hora?.toString() ?? '';
  return h.length >= 5 ? h.substring(0, 5) : h;
}
