// ============================================================
//  Práctica 12 — Fase 5: matriz de resiliencia RES-01 a RES-08
//  flutter test test/resiliencia_test.dart
//  Cada prueba describe el resultado ESPERADO. Las que fallen
//  "antes" son las que la optimización debe corregir.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskflow_wearable/api_cliente.dart';
import 'package:taskflow_wearable/main.dart';

/// Antes de la Práctica 12 el reloj escribía con PUT; después, con PATCH.
bool esEscritura(http.Request r) => r.method == 'PUT' || r.method == 'PATCH';

const _json = {'content-type': 'application/json; charset=utf-8'};
final _tareas = [
  {'id': 1, 'titulo': 'Estudiar', 'categoria': 'Escuela', 'estado': 'pendiente',
   'prioridad': 'alta', 'fecha': '2026-12-01', 'hora': '10:00:00', 'visibleEnWearable': true},
];

Future<void> avanzar(WidgetTester t, Duration total) async {
  const paso = Duration(milliseconds: 100);
  for (var e = Duration.zero; e < total; e += paso) {
    await t.pump(paso);
  }
}

void main() {
  late List<http.Request> peticiones;

  void servidor(Future<http.Response> Function(http.Request, int) responder) {
    peticiones = [];
    clienteHttp = MockClient((req) async {
      peticiones.add(req);
      return responder(req, peticiones.where((p) => p.method == req.method).length);
    });
  }

  Future<void> abrirTareas(WidgetTester t) async {
    FlutterSecureStorage.setMockInitialValues({'tf_token': 'TOK', 'tf_nombre': 'Jorge', 'tf_correo': 'j@test.com'});
    await t.pumpWidget(const MaterialApp(home: PantallaTareas()));
    await avanzar(t, const Duration(seconds: 1));
  }

  final lista = (http.Request _, int __) async => http.Response(jsonEncode(_tareas), 200, headers: _json);
  int puts() => peticiones.where((p) => esEscritura(p)).length;

  testWidgets('RES-01 Pérdida de Internet durante una consulta -> error controlado', (t) async {
    servidor((_, __) async => throw const SocketException('sin red'));
    await abrirTareas(t);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets('RES-02 Pérdida de Internet durante una escritura -> no confirma falsamente', (t) async {
    servidor((req, n) async {
      if (esEscritura(req)) throw const SocketException('sin red');
      return lista(req, n);
    });
    await abrirTareas(t);
    await t.tap(find.text('Listo'));
    await avanzar(t, const Duration(seconds: 15));
    expect(find.textContaining('No se pudo actualizar'), findsOneWidget);
  });

  testWidgets('RES-03 Servidor sin respuesta -> timeout controlado (máx. 15 s)', (t) async {
    servidor((_, __) => Completer<http.Response>().future); // nunca responde
    await abrirTareas(t);
    await avanzar(t, const Duration(seconds: 15));
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'Sin timeout la app espera para siempre');
  });

  testWidgets('RES-04 Respuesta HTTP 500 -> muestra error y conserva estabilidad', (t) async {
    servidor((_, __) async => http.Response('', 500));
    await abrirTareas(t);
    await avanzar(t, const Duration(seconds: 15));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('servidor'), findsOneWidget);
  });

  testWidgets('RES-05a Respuesta 401 -> cierra sesión y vuelve al login', (t) async {
    servidor((_, __) async => http.Response('', 401));
    await abrirTareas(t);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('RES-05b Respuesta 403 (así responde Railway a un token vencido) -> vuelve al login', (t) async {
    servidor((_, __) async => http.Response('', 403));
    await abrirTareas(t);
    await avanzar(t, const Duration(seconds: 2));
    expect(find.text('Inicia sesión'), findsOneWidget,
        reason: 'En producción un token vencido recibe 403, no 401');
  });

  testWidgets('RES-06 Recuperación de conexión -> al volver la red se restablece la lista', (t) async {
    var sinRed = true;
    servidor((req, n) async {
      if (sinRed) throw const SocketException('sin red');
      return lista(req, n);
    });
    await abrirTareas(t);
    await avanzar(t, const Duration(seconds: 15));
    sinRed = false;
    await t.tap(find.text('Pendiente'));
    await avanzar(t, const Duration(seconds: 2));
    expect(find.text('Estudiar'), findsOneWidget);
  });

  testWidgets('RES-07 Reintento de escritura -> reintenta con la misma Idempotency-Key, sin duplicar', (t) async {
    servidor((req, n) async {
      if (esEscritura(req) && n == 1) throw const SocketException('se cayó la respuesta');
      if (esEscritura(req)) return http.Response(req.body, 200, headers: _json);
      return lista(req, n);
    });
    await abrirTareas(t);
    await t.tap(find.text('Listo'));
    await avanzar(t, const Duration(seconds: 10));

    expect(puts(), 2, reason: 'Debe reintentar una vez de forma controlada');
    final llaves = peticiones.where((p) => esEscritura(p)).map((p) => p.headers['Idempotency-Key']).toSet();
    expect(llaves.length, 1, reason: 'Ambos intentos deben llevar la misma llave');
    expect(llaves.first, isNotNull);
    expect(find.textContaining('No se pudo actualizar'), findsNothing);
  });

  testWidgets('RES-08 Respuesta tardía -> un doble toque no envía dos escrituras', (t) async {
    servidor((req, n) async {
      if (esEscritura(req)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        return http.Response(req.body, 200, headers: _json);
      }
      return lista(req, n);
    });
    await abrirTareas(t);
    await t.tap(find.text('Listo'));
    await t.pump(const Duration(milliseconds: 200));
    if (find.text('Listo').evaluate().isNotEmpty) {
      await t.tap(find.text('Listo'), warnIfMissed: false);
    }
    await avanzar(t, const Duration(seconds: 6));
    expect(puts(), 1, reason: 'El botón sigue activo mientras espera: se envían dos PUT');
  });
}
