// ============================================================
//  Práctica 11 — WB unitarias de la lógica de procesamiento
//  flutter test test/logica_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_wearable/logica.dart';

void main() {
  final tareas = [
    {'id': 1, 'titulo': 'A', 'estado': 'pendiente'},
    {'id': 2, 'titulo': 'B', 'estado': 'progreso'},
    {'id': 3, 'titulo': 'C', 'estado': 'pendiente'},
    {'id': 4, 'titulo': 'D', 'estado': 'finalizado'},
  ];

  group('filtrarPorEstado', () {
    test('Entrada válida: devuelve solo las pendientes, en orden', () {
      final r = filtrarPorEstado(tareas, 'pendiente');
      expect(r.map((t) => t['id']), [1, 3]);
    });

    test('Lista vacía: devuelve lista vacía sin error', () {
      expect(filtrarPorEstado([], 'pendiente'), isEmpty);
    });

    test('Filtro sin coincidencias: lista vacía', () {
      expect(filtrarPorEstado(tareas, 'archivada'), isEmpty);
    });

    test('Tarea sin campo estado (null) se descarta', () {
      expect(filtrarPorEstado([{'id': 9}], 'pendiente'), isEmpty);
    });

    test('Defecto WB-05: "Pendiente" con mayúscula (como lo muestra la web) no se reconoce', () {
      // La web muestra "Pendiente"; si algún cliente la guarda así, el reloj la oculta.
      final r = filtrarPorEstado([{'id': 7, 'estado': 'Pendiente'}], 'pendiente');
      expect(r.length, 1, reason: 'La comparación distingue mayúsculas: la tarea desaparece del reloj');
    });
  });

  group('formatearHora', () {
    test('Hora completa "10:30:00" -> "10:30"', () {
      expect(formatearHora('10:30:00'), '10:30');
    });

    test('Valor límite: exactamente 5 caracteres "09:05" -> "09:05"', () {
      expect(formatearHora('09:05'), '09:05');
    });

    test('Hora nula -> cadena vacía', () {
      expect(formatearHora(null), '');
    });

    test('Defecto WB-04: hora corta "9:5" no debe tumbar la tarjeta (RangeError)', () {
      expect(() => formatearHora('9:5'), returnsNormally,
          reason: 'substring(0, 5) lanza RangeError con menos de 5 caracteres');
    });
  });
}
