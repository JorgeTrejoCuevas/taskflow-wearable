// ============================================================
//  Práctica 11 — WB de la app móvil (widget tests)
//  Métodos críticos probados por sus caminos internos:
//   - _PantallaLoginState._login        (validación / autenticación)
//   - _PantallaTareasState._cargarTareas (consumo de servicio)
//   - _PantallaTareasState._cambiarEstado (comunicación / escritura)
//   - _TarjetaTarea.build                (decisiones por estado)
//  El servidor se simula con MockClient: no se usa la red real.
//  Las pruebas "Defecto" esperan el comportamiento CORRECTO;
//  si fallan, el fallo es la evidencia.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskflow_wearable/api_cliente.dart';
import 'package:taskflow_wearable/main.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

final _tareas = [
  {'id': 1, 'titulo': 'Estudiar', 'categoria': 'Escuela', 'estado': 'pendiente',
   'prioridad': 'alta', 'fecha': '2026-12-01', 'hora': '10:00:00', 'visibleEnWearable': true},
  {'id': 2, 'titulo': 'Programar', 'categoria': 'Trabajo', 'estado': 'progreso',
   'prioridad': 'media', 'fecha': '2026-12-01', 'hora': '12:30:00', 'visibleEnWearable': true},
  {'id': 3, 'titulo': 'Correr', 'categoria': 'Salud', 'estado': 'finalizado',
   'prioridad': 'baja', 'fecha': '2026-12-01', 'hora': '07:00:00', 'visibleEnWearable': true},
];

/// Avanza el tiempo lo suficiente para que terminen las llamadas simuladas y la navegación.
Future<void> asentar(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late List<http.Request> peticiones;

  /// Instala un servidor simulado. [responder] decide la respuesta según la petición.
  void servidor(Future<http.Response> Function(http.Request) responder) {
    peticiones = [];
    clienteHttp = MockClient((req) async {
      peticiones.add(req);
      return responder(req);
    });
  }

  Future<void> abrirLogin(WidgetTester t) async {
    FlutterSecureStorage.setMockInitialValues({});
    await t.pumpWidget(const MaterialApp(home: PantallaLogin()));
  }

  Future<void> escribirYEntrar(WidgetTester t, String correo, String pass) async {
    await t.enterText(find.byType(TextField).at(0), correo);
    await t.enterText(find.byType(TextField).at(1), pass);
    await t.tap(find.text('Entrar'));
    await asentar(t);
  }

  Future<void> abrirTareas(WidgetTester t) async {
    FlutterSecureStorage.setMockInitialValues({'tf_token': 'TOK', 'tf_nombre': 'Jorge', 'tf_correo': 'j@test.com'});
    await t.pumpWidget(const MaterialApp(home: PantallaTareas()));
    await asentar(t);
  }

  // ── _login ────────────────────────────────────────────────
  group('WB _login', () {
    testWidgets('C1 200: guarda token y navega a tareas', (t) async {
      servidor((req) async => req.url.path == '/api/auth/login'
          ? http.Response(jsonEncode({'token': 'TOK', 'nombre': 'Jorge', 'correo': 'j@test.com'}), 200, headers: _json)
          : http.Response(jsonEncode(_tareas), 200, headers: _json));
      await abrirLogin(t);
      await escribirYEntrar(t, ' j@test.com ', 'Clave123!');

      expect(find.text('Estudiar'), findsOneWidget); // ya está en PantallaTareas
      expect(await const FlutterSecureStorage().read(key: 'tf_token'), 'TOK');
      final cuerpo = jsonDecode(peticiones.first.body);
      expect(cuerpo['correo'], 'j@test.com', reason: 'el correo se envía sin espacios (trim)');
    });

    testWidgets('C2 401: muestra "Credenciales incorrectas" y no guarda token', (t) async {
      servidor((_) async => http.Response('{"error":"x"}', 401, headers: _json));
      await abrirLogin(t);
      await escribirYEntrar(t, 'j@test.com', 'mala');

      expect(find.text('Credenciales incorrectas'), findsOneWidget);
      expect(await const FlutterSecureStorage().read(key: 'tf_token'), isNull);
    });

    testWidgets('C3 excepción (sin red): muestra "Sin conexión" y reactiva el botón', (t) async {
      servidor((_) async => throw const SocketException('sin red'));
      await abrirLogin(t);
      await escribirYEntrar(t, 'j@test.com', 'x');

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget); // _cargando volvió a false (finally)
    });

    testWidgets('Defecto WB-05: con campos vacíos NO debe llamar al servidor', (t) async {
      servidor((_) async => http.Response('{}', 401, headers: _json));
      await abrirLogin(t);
      await t.tap(find.text('Entrar'));
      await asentar(t);

      expect(peticiones, isEmpty, reason: 'No hay validación local: se envía la petición con correo y contraseña vacíos');
    });

    testWidgets('Defecto WB-04: un 500 del servidor no debe mostrarse como "Credenciales incorrectas"', (t) async {
      servidor((_) async => http.Response('', 500));
      await abrirLogin(t);
      await escribirYEntrar(t, 'j@test.com', 'Clave123!');

      expect(find.text('Credenciales incorrectas'), findsNothing,
          reason: 'Cualquier código distinto de 200 se reporta como contraseña incorrecta');
    });
  });

  // ── _cargarTareas ─────────────────────────────────────────
  group('WB _cargarTareas', () {
    testWidgets('C1 200: envía el token y muestra solo las pendientes', (t) async {
      servidor((_) async => http.Response(jsonEncode(_tareas), 200, headers: _json));
      await abrirTareas(t);

      expect(peticiones.first.headers['Authorization'], 'Bearer TOK');
      expect(find.text('Estudiar'), findsOneWidget);
      expect(find.text('Programar'), findsNothing);
      expect(find.text('10:00'), findsOneWidget); // formatearHora
    });

    testWidgets('C1b lista vacía: muestra "Sin tareas pendiente"', (t) async {
      servidor((_) async => http.Response('[]', 200, headers: _json));
      await abrirTareas(t);
      expect(find.text('Sin tareas pendiente'), findsOneWidget);
    });

    testWidgets('C2 401: borra la sesión y regresa al login', (t) async {
      servidor((_) async => http.Response('', 401));
      await abrirTareas(t);

      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(await const FlutterSecureStorage().read(key: 'tf_token'), isNull);
    });

    testWidgets('C3 excepción: muestra "Sin conexión"', (t) async {
      servidor((_) async => throw const SocketException('sin red'));
      await abrirTareas(t);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('Defecto WB-04: con 500 la pantalla debe salir del estado de carga', (t) async {
      servidor((_) async => http.Response('', 500));
      await abrirTareas(t);

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'No hay rama para códigos distintos de 200/401: el spinner se queda para siempre');
    });
  });

  // ── _TarjetaTarea: decisiones por estado ──────────────────
  group('WB _TarjetaTarea (if por estado)', () {
    testWidgets('pendiente -> Iniciar/Listo; progreso -> Finalizar/Pausar; finalizado -> Reabrir', (t) async {
      servidor((_) async => http.Response(jsonEncode(_tareas), 200, headers: _json));
      await abrirTareas(t);
      expect(find.text('Iniciar'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);

      await t.tap(find.text('Progreso'));
      await asentar(t);
      expect(find.text('Finalizar'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);

      await t.tap(find.text('Finalizado'));
      await asentar(t);
      expect(find.text('Reabrir'), findsOneWidget);
      expect(find.text('Iniciar'), findsNothing);
    });
  });

  // ── _cambiarEstado ────────────────────────────────────────
  group('WB _cambiarEstado', () {
    testWidgets('C1: "Listo" envía PATCH /api/tareas/1/estado solo con el estado y recarga', (t) async {
      servidor((req) async => req.method == 'PATCH'
          ? http.Response(req.body, 200, headers: _json)
          : http.Response(jsonEncode(_tareas), 200, headers: _json));
      await abrirTareas(t);
      await t.tap(find.text('Listo'));
      await asentar(t);

      final put = peticiones.firstWhere((p) => p.method == 'PATCH');
      expect(put.url.path, '/api/tareas/1/estado');
      final cuerpo = jsonDecode(put.body);
      expect(cuerpo['estado'], 'finalizado');
      expect(cuerpo.containsKey('titulo'), isFalse, reason: 'Práctica 12: ya no reenvía la tarea completa');
      expect(put.headers['Idempotency-Key'], isNotNull);
      expect(peticiones.where((p) => p.method == 'GET').length, 2, reason: 'recarga la lista');
    });

    testWidgets('C2 excepción en PUT: muestra "No se pudo actualizar"', (t) async {
      servidor((req) async {
        if (req.method == 'PATCH') throw const SocketException('sin red');
        return http.Response(jsonEncode(_tareas), 200, headers: _json);
      });
      await abrirTareas(t);
      await t.tap(find.text('Listo'));
      for (var i = 0; i < 4; i++) {
        await asentar(t); // los reintentos esperan 0.5 s y 1 s
      }
      expect(find.text('No se pudo actualizar'), findsOneWidget);
    });

    testWidgets('Defecto WB-04: un PUT con 500 debe avisar al usuario (no parecer exitoso)', (t) async {
      servidor((req) async => req.method == 'PATCH'
          ? http.Response('', 500)
          : http.Response(jsonEncode(_tareas), 200, headers: _json));
      await abrirTareas(t);
      await t.tap(find.text('Listo'));
      await asentar(t);

      expect(find.text('No se pudo actualizar'), findsOneWidget,
          reason: '_cambiarEstado ignora el statusCode: un error del servidor se ve como éxito');
    });
  });

  // ── WB-06: interfaz en pantalla de reloj ──────────────────
  group('WB-06 interfaz', () {
    testWidgets('Pantalla de tareas en 390x390 sin desbordes y tiempo de render', (t) async {
      t.view.physicalSize = const Size(390, 390);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      final muchas = List.generate(200, (i) => {
            'id': i, 'titulo': 'Tarea con un título bastante largo número $i', 'categoria': 'Escuela',
            'estado': 'pendiente', 'hora': '10:00:00'});
      servidor((_) async => http.Response(jsonEncode(muchas), 200, headers: _json));

      final reloj = Stopwatch()..start();
      await abrirTareas(t);
      reloj.stop();
      // ignore: avoid_print
      print('[WB-06] carga + render de 200 tareas en 390x390: ${reloj.elapsedMilliseconds} ms (entorno de prueba)');

      expect(t.takeException(), isNull);
      expect(find.text('Iniciar'), findsOneWidget);
    });
  });
}
