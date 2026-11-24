// ============================================================
//  TaskFlow Wearable — main.dart
//  App para smartwatch Wear OS
//  Conectada al backend Spring Boot en Railway
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_cliente.dart'; // Práctica 11: cliente HTTP reemplazable en pruebas
import 'logica.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String API_URL = 'https://taskflow-api-production-eb68.up.railway.app';
const _storage = FlutterSecureStorage();
const _keyToken = 'tf_token';
const _keyNombre = 'tf_nombre';
const _keyCorreo = 'tf_correo';

void main() {
  runApp(const TaskFlowWearableApp());
}

class TaskFlowWearableApp extends StatelessWidget {
  const TaskFlowWearableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF534AB7),
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const PantallaInicio(),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  PANTALLA INICIO
// ════════════════════════════════════════════════════════════
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final token = await _storage.read(key: _keyToken);
    if (!mounted) return;
    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PantallaTareas()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF534AB7))),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  PANTALLA LOGIN
// ════════════════════════════════════════════════════════════
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  String _error = '';

  Future<void> _login() async {
    // Práctica 12: validación local antes de llamar al servidor
    if (_correoCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña');
      return;
    }
    setState(() {
      _cargando = true;
      _error = '';
    });
    try {
      final res = await clienteHttp.post(
        Uri.parse('$API_URL/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': _correoCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      ).timeout(tiempoLimite);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _storage.write(key: _keyToken, value: data['token']);
        await _storage.write(key: _keyNombre, value: data['nombre']);
        await _storage.write(key: _keyCorreo, value: data['correo']);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PantallaTareas()),
        );
      } else if (res.statusCode >= 500) {
        setState(() => _error = 'Error del servidor (${res.statusCode})');
      } else {
        setState(() => _error = 'Credenciales incorrectas');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Sin conexión');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    // Práctica 12: liberar recursos
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.asset('assets/taskflow-logo.png'),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'TaskFlow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Inicia sesión',
                style: TextStyle(color: Colors.white54, fontSize: 9),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _error,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _correoCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Correo',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white38,
                    size: 13,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.white38,
                    size: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF534AB7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  PANTALLA TAREAS
// ════════════════════════════════════════════════════════════
class PantallaTareas extends StatefulWidget {
  const PantallaTareas({super.key});

  @override
  State<PantallaTareas> createState() => _PantallaTareasState();
}

class _PantallaTareasState extends State<PantallaTareas> {
  List<dynamic> _tareas = [];
  bool _cargando = true;
  String _error = '';
  String _nombre = '';
  int _indice = 0;
  String _filtro = 'pendiente';
  int _peticionActual = 0; // Práctica 12: ignora respuestas viejas
  bool _actualizando = false; // Práctica 12: evita dobles envíos

  final List<String> _filtros = ['pendiente', 'progreso', 'finalizado'];
  final Map<String, Color> _colores = {
    'pendiente': const Color(0xFFAFA9EC),
    'progreso': const Color(0xFF1D9E75),
    'finalizado': const Color(0xFF888780),
  };

  @override
  void initState() {
    super.initState();
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    final reloj = Stopwatch()..start(); // Práctica 12: medición
    final miPeticion = ++_peticionActual;
    setState(() {
      _cargando = true;
      _error = '';
    });
    try {
      final token = await _storage.read(key: _keyToken);
      final nombre = await _storage.read(key: _keyNombre);
      setState(() => _nombre = nombre ?? '');

      // Práctica 12: pide solo las tareas del filtro (antes descargaba todas)
      final res = await clienteHttp.get(
        Uri.parse('$API_URL/api/tareas/estado/$_filtro'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(tiempoLimite);
      if (miPeticion != _peticionActual || !mounted) return;
      debugPrint('[PERF] GET /api/tareas -> ${res.statusCode} en ${reloj.elapsedMilliseconds} ms, ${res.bodyBytes.length} bytes');

      if (res.statusCode == 200) {
        final todas = jsonDecode(res.body) as List;
        setState(() {
          _tareas = filtrarPorEstado(todas, _filtro);
          _indice = 0;
          _cargando = false;
        });
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        await _sesionVencida();
      } else {
        // Práctica 12: antes no había rama aquí y la pantalla se quedaba cargando
        setState(() {
          _error = 'Error del servidor (${res.statusCode})';
          _cargando = false;
        });
      }
    } catch (e) {
      if (miPeticion != _peticionActual || !mounted) return;
      setState(() {
        _error = 'Sin conexión';
        _cargando = false;
      });
    }
  }

  Future<void> _sesionVencida() async {
    await _storage.deleteAll();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
    );
  }

  Future<void> _cambiarFiltro(String filtro) async {
    setState(() => _filtro = filtro);
    await _cargarTareas();
  }

  Future<void> _cambiarEstado(Map tarea, String nuevoEstado) async {
    if (_actualizando) return; // Práctica 12: ignora el doble toque
    _actualizando = true;
    final reloj = Stopwatch()..start(); // Práctica 12: medición
    final llave = nuevaLlaveIdempotencia();
    try {
      final token = await _storage.read(key: _keyToken);
      // Práctica 12: PATCH solo del estado, con reintento y la misma llave
      final res = await conReintentos((intento) => clienteHttp.patch(
            Uri.parse('$API_URL/api/tareas/${tarea['id']}/estado'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Idempotency-Key': llave,
            },
            body: jsonEncode({'estado': nuevoEstado}),
          ).timeout(tiempoLimite));
      debugPrint('[PERF] PATCH /api/tareas/${tarea['id']}/estado -> ${res.statusCode} en ${reloj.elapsedMilliseconds} ms');
      if (!mounted) return;
      if (res.statusCode == 200) {
        await _cargarTareas();
        debugPrint('[PERF] operación completa (PATCH + recarga) en ${reloj.elapsedMilliseconds} ms');
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        await _sesionVencida();
      } else {
        setState(() => _error = 'No se pudo actualizar');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo actualizar');
    } finally {
      _actualizando = false;
    }
  }

  Future<void> _cerrarSesion() async {
    await _storage.deleteAll();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset('assets/taskflow-logo.png'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _cerrarSesion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout, color: Colors.redAccent, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'Salir',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Filtros
            SizedBox(
              height: 20,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: _filtros.map((f) {
                  final activo = f == _filtro;
                  return GestureDetector(
                    onTap: () => _cambiarFiltro(f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: activo ? _colores[f] : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f[0].toUpperCase() + f.substring(1),
                        style: TextStyle(
                          color: activo ? Colors.white : Colors.white54,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Contenido
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF534AB7),
                        strokeWidth: 2,
                      ),
                    )
                  : _error.isNotEmpty
                  ? Center(
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 9,
                        ),
                      ),
                    )
                  : _tareas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: _colores[_filtro],
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sin tareas $_filtro',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    )
                  : PageView.builder(
                      itemCount: _tareas.length,
                      onPageChanged: (i) => setState(() => _indice = i),
                      itemBuilder: (_, i) => _TarjetaTarea(
                        tarea: _tareas[i],
                        color: _colores[_tareas[i]['estado']] ?? Colors.white38,
                        onCambiarEstado: _cambiarEstado,
                      ),
                    ),
            ),
            // Indicador de página
            if (_tareas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                // Práctica 12: con más de 7 tareas se muestra "3 / 57" (antes se desbordaba)
                child: _tareas.length > 7
                    ? Text(
                        '${_indice + 1} / ${_tareas.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 8),
                      )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _tareas.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _indice ? 10 : 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == _indice
                            ? const Color(0xFF534AB7)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TARJETA DE TAREA
// ════════════════════════════════════════════════════════════
class _TarjetaTarea extends StatelessWidget {
  final Map tarea;
  final Color color;
  final Function(Map, String) onCambiarEstado;

  const _TarjetaTarea({
    required this.tarea,
    required this.color,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final estado = tarea['estado'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            formatearHora(tarea['hora']),
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(height: 3),
          Text(
            tarea['titulo'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tarea['categoria'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (estado == 'pendiente') ...[
                _BotonAccion(
                  icono: Icons.play_arrow,
                  color: const Color(0xFF1D9E75),
                  label: 'Iniciar',
                  onTap: () => onCambiarEstado(tarea, 'progreso'),
                ),
                const SizedBox(width: 6),
                _BotonAccion(
                  icono: Icons.check,
                  color: const Color(0xFF534AB7),
                  label: 'Listo',
                  onTap: () => onCambiarEstado(tarea, 'finalizado'),
                ),
              ],
              if (estado == 'progreso') ...[
                _BotonAccion(
                  icono: Icons.check,
                  color: const Color(0xFF534AB7),
                  label: 'Finalizar',
                  onTap: () => onCambiarEstado(tarea, 'finalizado'),
                ),
                const SizedBox(width: 6),
                _BotonAccion(
                  icono: Icons.pause,
                  color: Colors.white24,
                  label: 'Pausar',
                  onTap: () => onCambiarEstado(tarea, 'pendiente'),
                ),
              ],
              if (estado == 'finalizado')
                _BotonAccion(
                  icono: Icons.refresh,
                  color: Colors.white24,
                  label: 'Reabrir',
                  onTap: () => onCambiarEstado(tarea, 'pendiente'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOTÓN DE ACCIÓN
// ════════════════════════════════════════════════════════════
class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _BotonAccion({
    required this.icono,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icono, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 7),
          ),
        ],
      ),
    );
  }
}
