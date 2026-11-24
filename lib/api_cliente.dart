// ============================================================
//  TaskFlow Wearable — api_cliente.dart  (Prácticas 11 y 12)
//  - Un solo cliente HTTP para toda la app (reutiliza conexiones).
//  - Práctica 12: tiempo límite, reintento con espera progresiva
//    (exponential backoff) y llave de idempotencia.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

http.Client clienteHttp = http.Client();

/// Ninguna petición puede esperar más que esto (antes: espera infinita).
const Duration tiempoLimite = Duration(seconds: 10);

/// Errores de red que vale la pena reintentar.
bool esErrorDeRed(Object e) =>
    e is SocketException || e is TimeoutException || e is http.ClientException;

/// Ejecuta [accion] y, si falla por red, la reintenta con espera progresiva:
/// 0.5 s, 1 s, 2 s... hasta [intentos] veces en total.
Future<T> conReintentos<T>(
  Future<T> Function(int intento) accion, {
  int intentos = 3,
  Duration esperaInicial = const Duration(milliseconds: 500),
}) async {
  var espera = esperaInicial;
  for (var intento = 1;; intento++) {
    try {
      return await accion(intento);
    } catch (e) {
      if (!esErrorDeRed(e) || intento >= intentos) rethrow;
      await Future<void>.delayed(espera);
      espera *= 2;
    }
  }
}

/// Identificador único por operación; se repite igual en cada reintento.
String nuevaLlaveIdempotencia() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
