// ============================================================
//  Práctica 11 — Prueba de arranque de la app
//  (Reemplaza la prueba por defecto de Flutter, que buscaba un
//   contador "MyApp" que no existe y no compilaba.)
// ============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_wearable/main.dart';

void main() {
  testWidgets('Sin token guardado, la app abre en la pantalla de login', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    await t.pumpWidget(const TaskFlowWearableApp());
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
