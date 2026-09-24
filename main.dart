import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

/// ---------------------------------------------------------------------
/// MODOS DE JUEGO
/// ---------------------------------------------------------------------

enum GameMode { clasico, contraTiempo, imposible, letra }

class GameModeConfig {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final int rangoMin;
  final int rangoMax;
  final int intentosIniciales;
  final int? tiempoLimiteSegundos;
  final bool esLetra;

  const GameModeConfig({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.rangoMin,
    required this.rangoMax,
    required this.intentosIniciales,
    this.tiempoLimiteSegundos,
    this.esLetra = false,
  });
}

const Map<GameMode, GameModeConfig> kGameModes = {
  GameMode.clasico: GameModeConfig(
    titulo: '🧠 Clásico',
    descripcion: 'Adivina el número del 1 al 100.',
    icono: Icons.bolt,
    rangoMin: 1,
    rangoMax: 100,
    intentosIniciales: 5,
  ),
  GameMode.contraTiempo: GameModeConfig(
    titulo: '⚡ Contra el tiempo',
    descripcion: 'Tienes 30 segundos para encontrarlo.',
    icono: Icons.timer,
    rangoMin: 1,
    rangoMax: 100,
    intentosIniciales: 10,
    tiempoLimiteSegundos: 30,
  ),
  GameMode.imposible: GameModeConfig(
    titulo: '🔥 Imposible',
    descripcion: 'Del 1 al 1.000 y solo 7 intentos.',
    icono: Icons.local_fire_department,
    rangoMin: 1,
    rangoMax: 1000,
    intentosIniciales: 7,
  ),
  GameMode.letra: GameModeConfig(
    titulo: '🔤 Letras',
    descripcion: 'Adivina la letra secreta (A-Z).',
    icono: Icons.abc,
    rangoMin: 65,
    rangoMax: 90,
    intentosIniciales: 5,
    esLetra: true,
  ),
};

/// ---------------------------------------------------------------------
/// ESTADÍSTICAS (persistidas en el dispositivo con SharedPreferences)
/// ---------------------------------------------------------------------

class EstadisticasJuego {
  int partidas;
  int victorias;
  int rachaActual;
  int mejorRacha;
  int? mejorPartida; // menor número de intentos en una victoria

  EstadisticasJuego({
    this.partidas = 0,
    this.victorias = 0,
    this.rachaActual = 0,
    this.mejorRacha = 0,
    this.mejorPartida,
  });

  double get precision => partidas == 0 ? 0 : (victorias / partidas) * 100;

  Map<String, dynamic> toJson() => {
    'partidas': partidas,
    'victorias': victorias,
    'rachaActual': rachaActual,
    'mejorRacha': mejorRacha,
    'mejorPartida': mejorPartida,
  };

  factory EstadisticasJuego.fromJson(Map<String, dynamic> json) =>
      EstadisticasJuego(
        partidas: json['partidas'] ?? 0,
        victorias: json['victorias'] ?? 0,
        rachaActual: json['rachaActual'] ?? 0,
        mejorRacha: json['mejorRacha'] ?? 0,
        mejorPartida: json['mejorPartida'],
      );
}

class EstadisticasService {
  static const _key = 'adivina_estadisticas_v1';

  static Future<EstadisticasJuego> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return EstadisticasJuego();
    try {
      return EstadisticasJuego.fromJson(jsonDecode(raw));
    } catch (_) {
      return EstadisticasJuego();
    }
  }

  static Future<void> _guardar(EstadisticasJuego stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(stats.toJson()));
  }

  /// Registra el resultado de una partida y devuelve las estadísticas
  /// actualizadas.
  static Future<EstadisticasJuego> registrarPartida({
    required bool gano,
    required int intentosUsados,
  }) async {
    final stats = await cargar();
    stats.partidas++;
    if (gano) {
      stats.victorias++;
      stats.rachaActual++;
      if (stats.rachaActual > stats.mejorRacha) {
        stats.mejorRacha = stats.rachaActual;
      }
      if (stats.mejorPartida == null || intentosUsados < stats.mejorPartida!) {
        stats.mejorPartida = intentosUsados;
      }
    } else {
      stats.rachaActual = 0;
    }
    await _guardar(stats);
    return stats;
  }
}

/// Formateador que convierte lo que se escribe a mayúsculas al instante.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// ---------------------------------------------------------------------
/// APP RAÍZ (maneja el tema claro/oscuro)
/// ---------------------------------------------------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adivina el Número o la Letra',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4361EE),
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B93FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Poppins',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121016),
      ),
      home: StartScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// PANTALLA DE INICIO: "¿Cómo quieres jugar?" + tarjeta de estadísticas
/// ---------------------------------------------------------------------

class StartScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const StartScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  EstadisticasJuego? _stats;

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    final stats = await EstadisticasService.cargar();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _jugar(GameMode modo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(mode: modo)),
    );
    // Al volver de la partida, refrescamos las estadísticas.
    _cargarStats();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.isDarkMode;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    const Color(0xFF13204A),
                    const Color(0xFF1E3A8A),
                    const Color(0xFF0B1226),
                  ]
                : [
                    const Color(0xFF4361EE),
                    const Color(0xFF4895EF),
                    const Color(0xFFBFD3FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: dark
                            ? 'Cambiar a modo claro'
                            : 'Cambiar a modo oscuro',
                        icon: Icon(
                          dark ? Icons.light_mode : Icons.dark_mode,
                          color: const Color(0xFF4361EE),
                        ),
                        onPressed: widget.onToggleTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '🎲',
                  style: TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Cómo quieres jugar?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 22),
                _modeCard(GameMode.clasico),
                const SizedBox(height: 14),
                _modeCard(GameMode.contraTiempo),
                const SizedBox(height: 14),
                _modeCard(GameMode.imposible),
                const SizedBox(height: 14),
                _modeCard(GameMode.letra),
                const SizedBox(height: 26),
                _buildStatsCard(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard(GameMode modo) {
    final config = kGameModes[modo]!;
    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _jugar(modo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF4361EE).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.icono,
                  color: const Color(0xFF4361EE),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      config.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _stats;
    if (stats == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (stats.partidas == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: const Text(
          '🎯 Juega tu primera partida para empezar a acumular estadísticas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Tus estadísticas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _statRow('🎯', 'Partidas', '${stats.partidas}'),
          _statRow('🏆', 'Victorias', '${stats.victorias}'),
          _statRow('🔥', 'Racha actual', '${stats.rachaActual}'),
          _statRow(
            '⚡',
            'Mejor partida',
            stats.mejorPartida == null
                ? '—'
                : '${stats.mejorPartida} intentos',
          ),
          _statRow(
            '🎯',
            'Precisión',
            '${stats.precision.toStringAsFixed(0)}%',
          ),
          if (stats.rachaActual >= 2) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '🔥 ¡Llevas ${stats.rachaActual} victorias seguidas!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// PANTALLA DE JUEGO
/// ---------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final GameMode mode;

  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const String _alfabeto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const List<String> _vocales = ['A', 'E', 'I', 'O', 'U'];

  late GameModeConfig _config;

  // El "secreto" se guarda siempre como int: el número en sí, o el código
  // ASCII de la letra si el modo es de letras.
  late int _secreto;

  int _rangoMin = 1;
  int _rangoMax = 100;

  int _intentos = 0;
  late int _intentosRestantes;
  String _mensaje = '';
  final TextEditingController _controller = TextEditingController();
  bool _juegoTerminado = false;
  bool _juegoPerdido = false;
  bool _statsRegistradas = false;

  // Sistema de pistas: se genera una lista de pistas posibles al iniciar
  // cada partida y se van revelando de una en una, cada una cuesta 1 vida.
  List<String> _pistasDisponibles = [];
  int _pistasReveladas = 0;

  // Temporizador (solo para el modo "Contra el tiempo")
  Timer? _timer;
  int _tiempoRestante = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get _esLetra => _config.esLetra;

  @override
  void initState() {
    super.initState();
    _config = kGameModes[widget.mode]!;
    _controller.addListener(() {
      setState(() {});
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _iniciarJuego();
  }

  void _iniciarJuego() {
    _timer?.cancel();
    setState(() {
      _secreto =
          _config.rangoMin +
          Random().nextInt(_config.rangoMax - _config.rangoMin + 1);
      _rangoMin = _config.rangoMin;
      _rangoMax = _config.rangoMax;
      _intentos = 0;
      _intentosRestantes = _config.intentosIniciales;
      _juegoTerminado = false;
      _juegoPerdido = false;
      _statsRegistradas = false;
      _pistasReveladas = 0;
      _pistasDisponibles = _generarPistas();
      _mensaje = _mensajeInicial();
      _controller.clear();
      _tiempoRestante = _config.tiempoLimiteSegundos ?? 0;
    });

    if (_config.tiempoLimiteSegundos != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_juegoTerminado || _juegoPerdido) {
          t.cancel();
          return;
        }
        setState(() {
          _tiempoRestante--;
          if (_tiempoRestante <= 0) {
            _tiempoRestante = 0;
            _juegoPerdido = true;
            _mensaje =
                '⏰ ¡SE ACABÓ EL TIEMPO! ⏰\n'
                'El ${_esLetra ? "letra" : "número"} secreto era ${_formatValor(_secreto)}';
            t.cancel();
            _registrarResultado();
          }
        });
      });
    }

    _animationController.reset();
    _animationController.forward();
  }

  String _mensajeInicial() {
    if (_esLetra) {
      const mensajes = [
        '🔤 ¡Adivina la letra secreta! (A-Z)',
        '🧩 Una letra se esconde en el abecedario...',
        '🌟 Piensa bien y prueba tu suerte',
      ];
      return mensajes[Random().nextInt(mensajes.length)];
    }
    switch (widget.mode) {
      case GameMode.contraTiempo:
        return '⚡ ¡30 segundos en el reloj! Encuentra el número.';
      case GameMode.imposible:
        return '🔥 Modo imposible: 1 al 1.000, solo 7 intentos.';
      default:
        const mensajes = [
          '🎯 ¡Adivina el número secreto! (1-100)',
          '🔮 Desafío mental activo... ¿Cuál será?',
          '🌟 Concéntrate y prueba tu suerte',
        ];
        return mensajes[Random().nextInt(mensajes.length)];
    }
  }

  String _formatValor(int v) => _esLetra ? String.fromCharCode(v) : '$v';

  /// Genera una lista de pistas válidas para el secreto de esta partida.
  List<String> _generarPistas() {
    if (_esLetra) return _generarPistasLetra();
    return _generarPistasNumero();
  }

  List<String> _generarPistasNumero() {
    final List<String> pistas = [];
    final int min = _config.rangoMin;
    final int max = _config.rangoMax;

    // 1) Par / impar
    final bool esPar = _secreto % 2 == 0;
    pistas.add('💡 El número es ${esPar ? "PAR" : "IMPAR"}.');

    // 2) Rango estrecho alrededor del secreto
    final int ventana = ((max - min) / 8).round().clamp(3, 100);
    final int lo = (_secreto - ventana).clamp(min, max);
    final int hi = (_secreto + ventana).clamp(min, max);
    pistas.add('💡 El número está entre $lo y $hi.');

    // 3) Mayor que
    final int umbralMayor = (_secreto - (ventana ~/ 2)).clamp(min, max - 1);
    pistas.add('💡 El número es mayor que $umbralMayor.');

    // 4) Menor que
    final int umbralMenor = (_secreto + (ventana ~/ 2)).clamp(min + 1, max);
    pistas.add('💡 El número es menor que $umbralMenor.');

    // 5) Múltiplo de algo (si aplica), si no, dato de múltiplo negativo
    if (_secreto % 5 == 0) {
      pistas.add('💡 Es múltiplo de 5.');
    } else if (_secreto % 3 == 0) {
      pistas.add('💡 Es múltiplo de 3.');
    } else {
      pistas.add('💡 No es múltiplo de 5.');
    }

    pistas.shuffle();
    return pistas;
  }

  List<String> _generarPistasLetra() {
    final List<String> pistas = [];
    final bool esVocal = _vocales.contains(String.fromCharCode(_secreto));
    pistas.add('💡 La letra es una ${esVocal ? "VOCAL" : "CONSONANTE"}.');

    final int mitad = 65 + 12; // aprox. mitad del abecedario ('M')
    pistas.add(
      _secreto <= mitad
          ? '💡 Está en la primera mitad del abecedario (A-M).'
          : '💡 Está en la segunda mitad del abecedario (N-Z).',
    );

    final int ventana = 4;
    final int lo = (_secreto - ventana).clamp(65, 90);
    final int hi = (_secreto + ventana).clamp(65, 90);
    pistas.add(
      '💡 La letra está entre ${String.fromCharCode(lo)} y ${String.fromCharCode(hi)}.',
    );

    pistas.shuffle();
    return pistas;
  }

  void _usarPista() {
    if (_juegoTerminado || _juegoPerdido) return;
    if (_pistasReveladas >= _pistasDisponibles.length) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _intentosRestantes--;
      final String pista = _pistasDisponibles[_pistasReveladas];
      _pistasReveladas++;

      if (_intentosRestantes <= 0) {
        _juegoPerdido = true;
        _mensaje =
            '💀 ¡GAME OVER! 💀\n'
            'El ${_esLetra ? "letra" : "número"} secreto era ${_formatValor(_secreto)}';
        _registrarResultado();
      } else {
        _mostrarMensajeTemporal(
          '$pista (−1 vida)',
          Colors.indigo.shade400,
        );
      }
    });
  }

  void _verificarAdivinanza() {
    if (_juegoTerminado || _juegoPerdido) return;

    final String texto = _controller.text.trim();
    if (texto.isEmpty) {
      _mostrarMensajeTemporal(
        _esLetra
            ? '📝 ¡Ingresa una letra obligatoriamente!'
            : '📝 ¡Ingresa un número obligatoriamente!',
        Colors.amber.shade800,
      );
      return;
    }

    int? valor;
    if (_esLetra) {
      final String letra = texto.toUpperCase();
      if (letra.length == 1 && _alfabeto.contains(letra)) {
        valor = letra.codeUnitAt(0);
      }
    } else {
      final int? n = int.tryParse(texto);
      if (n != null && n >= _config.rangoMin && n <= _config.rangoMax) {
        valor = n;
      }
    }

    if (valor == null) {
      _mostrarMensajeTemporal(
        _esLetra
            ? '🚫 ¡Solo una letra de la A a la Z!'
            : '🚫 ¡Solo números enteros del ${_config.rangoMin} al ${_config.rangoMax}!',
        Colors.red.shade600,
      );
      return;
    }

    final int adivinanza = valor;
    final int diferencia = (adivinanza - _secreto).abs();

    setState(() {
      _intentos++;
      _intentosRestantes--;
      _controller.clear();

      if (adivinanza == _secreto) {
        _mensaje = _mensajeVictoria();
        _juegoTerminado = true;
        HapticFeedback.heavyImpact();
        _registrarResultado();
      } else if (_intentosRestantes <= 0) {
        _mensaje =
            '💀 ¡GAME OVER! 💀\n'
            'El ${_esLetra ? "letra" : "número"} secreto era ${_formatValor(_secreto)}';
        _juegoPerdido = true;
        HapticFeedback.heavyImpact();
        _registrarResultado();
      } else {
        if (adivinanza < _secreto) {
          _rangoMin = adivinanza;
        } else {
          _rangoMax = adivinanza;
        }
        final String temp = _temperatura(
          diferencia,
          _config.rangoMax - _config.rangoMin,
        );
        final String direccion = _esLetra
            ? (adivinanza < _secreto
                  ? '⬆️ Ve más adelante en el abecedario'
                  : '⬇️ Ve más atrás en el abecedario')
            : (adivinanza < _secreto ? '⬆️ Sube más' : '⬇️ Baja más');
        _mensaje = '$direccion. $temp\nTe quedan $_intentosRestantes';
        HapticFeedback.lightImpact();
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  String _mensajeVictoria() {
    return '🔥 ¡LEGENDARIO! ¡ACERTASTE! 🔥\n'
        'Lo lograste en $_intentos ${_intentos == 1 ? 'intento' : 'intentos'}';
  }

  void _registrarResultado() {
    if (_statsRegistradas) return;
    _statsRegistradas = true;
    EstadisticasService.registrarPartida(
      gano: _juegoTerminado,
      intentosUsados: _intentos,
    );
  }

  String _temperatura(int diferencia, int rangoMaximo) {
    final double proporcion = diferencia / rangoMaximo;
    if (proporcion <= 0.03) return '🔥🔥 ¡Ardiendo!';
    if (proporcion <= 0.10) return '🔥 Muy caliente';
    if (proporcion <= 0.25) return '🌤️ Tibio';
    return '❄️ Frío';
  }

  void _mostrarMensajeTemporal(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getMensajeColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_juegoTerminado) return Colors.green.shade600;
    if (_juegoPerdido) return Colors.red.shade600;
    if (_mensaje.contains('Sube') || _mensaje.contains('adelante')) {
      return Colors.blue.shade700;
    }
    if (_mensaje.contains('Baja') || _mensaje.contains('atrás')) {
      return Colors.orange.shade800;
    }
    return scheme.primary;
  }

  List<Color> _gradientColors(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (_esLetra) {
      return dark
          ? [
              const Color(0xFF0F3D3E),
              const Color(0xFF1B5E5A),
              const Color(0xFF102025),
            ]
          : [
              Colors.teal.shade400,
              Colors.cyan.shade200,
              Colors.lightBlue.shade100,
            ];
    }
    if (widget.mode == GameMode.contraTiempo) {
      return dark
          ? [
              const Color(0xFF4A1320),
              const Color(0xFF8A1E3A),
              const Color(0xFF26090B),
            ]
          : [
              const Color(0xFFEE4361),
              const Color(0xFFF84895),
              const Color(0xFFFFBFD3),
            ];
    }
    if (widget.mode == GameMode.imposible) {
      return dark
          ? [
              const Color(0xFF1A0F00),
              const Color(0xFF5E2A00),
              const Color(0xFF251500),
            ]
          : [
              Colors.deepOrange.shade400,
              Colors.orange.shade300,
              Colors.amber.shade100,
            ];
    }
    return dark
        ? [
            const Color(0xFF13204A),
            const Color(0xFF1E3A8A),
            const Color(0xFF0B1226),
          ]
        : [
            const Color(0xFF4361EE),
            const Color(0xFF4895EF),
            const Color(0xFFBFD3FF),
          ];
  }

  Color _accentColor(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (_esLetra) {
      return dark ? Colors.tealAccent.shade200 : Colors.teal.shade700;
    }
    if (widget.mode == GameMode.contraTiempo) {
      return dark ? const Color(0xFFFF8FA3) : const Color(0xFFEE4361);
    }
    if (widget.mode == GameMode.imposible) {
      return dark ? Colors.orange.shade300 : Colors.deepOrange.shade700;
    }
    return dark ? const Color(0xFF7B93FF) : const Color(0xFF4361EE);
  }

  Widget _rangoChip(String texto, Color color) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRangoBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color accent = _accentColor(context);

    final int totalMin = _config.rangoMin;
    final int totalMax = _config.rangoMax;
    final String minLabel = _formatValor(_rangoMin);
    final String maxLabel = _formatValor(_rangoMax);

    final double startFrac = (_rangoMin - totalMin) / (totalMax - totalMin);
    final double endFrac = (_rangoMax - totalMin) / (totalMax - totalMin);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📏 Rango posible',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const double chipHalf = 17;
              final double width = constraints.maxWidth;
              final double rawLeft = startFrac * width;
              final double rawWidth = (endFrac - startFrac) * width;
              final double barWidth = rawWidth < 8 ? 8 : rawWidth;
              final double leftPx = rawLeft.clamp(0.0, width - barWidth);

              return SizedBox(
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 13,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      top: 13,
                      left: leftPx,
                      width: barWidth,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent.withOpacity(0.75), accent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      top: 0,
                      left: (leftPx - chipHalf).clamp(
                        0.0,
                        width - chipHalf * 2,
                      ),
                      child: _rangoChip(minLabel, accent),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      top: 0,
                      left: (leftPx + barWidth - chipHalf).clamp(
                        0.0,
                        width - chipHalf * 2,
                      ),
                      child: _rangoChip(maxLabel, accent),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool peligro =
        _intentosRestantes <= 2 && !_juegoTerminado && !_juegoPerdido;
    final scheme = Theme.of(context).colorScheme;
    final bool hayPistasDisponibles =
        _pistasReveladas < _pistasDisponibles.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors(context),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Barra superior: volver + título del modo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Cambiar de modo',
                              icon: Icon(
                                Icons.arrow_back,
                                color: _accentColor(context),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _config.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Temporizador (solo modo Contra el tiempo)
                      if (_config.tiempoLimiteSegundos != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _tiempoRestante <= 10
                                ? Colors.red.shade100
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _tiempoRestante <= 10
                                  ? Colors.red.shade400
                                  : Colors.black12,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                color: _tiempoRestante <= 10
                                    ? Colors.red.shade700
                                    : _accentColor(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_tiempoRestante s',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _tiempoRestante <= 10
                                      ? Colors.red.shade700
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Encabezado con ícono vibrante
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor(context).withOpacity(0.35),
                              blurRadius: 25,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          _juegoTerminado
                              ? Icons.emoji_events
                              : (_juegoPerdido
                                    ? Icons.sentiment_very_dissatisfied
                                    : _config.icono),
                          size: 65,
                          color: _juegoTerminado
                              ? Colors.amber.shade700
                              : (_juegoPerdido
                                    ? Colors.red.shade600
                                    : _accentColor(context)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _esLetra
                              ? '🔤 Rango permitido: A a la Z (solo letras)'
                              : '🔢 Rango permitido: ${_config.rangoMin} al ${_config.rangoMax} (solo números)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildRangoBar(context),
                      const SizedBox(height: 16),

                      // Tarjeta de mensaje principal
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          _mensaje,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getMensajeColor(context),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Contador de vidas/intentos
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: peligro
                              ? Colors.red.shade100
                              : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: peligro
                                ? Colors.red.shade400
                                : Colors.amber.shade400,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              peligro
                                  ? Icons.local_fire_department
                                  : Icons.favorite,
                              color: peligro
                                  ? Colors.red.shade700
                                  : Colors.amber.shade800,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Vidas / Intentos: $_intentosRestantes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: peligro
                                    ? Colors.red.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Botón de pista (cuesta 1 vida)
                      TextButton.icon(
                        onPressed:
                            (!hayPistasDisponibles ||
                                _juegoTerminado ||
                                _juegoPerdido)
                            ? null
                            : _usarPista,
                        icon: Icon(
                          Icons.lightbulb,
                          color: hayPistasDisponibles
                              ? Colors.amber.shade300
                              : Colors.grey,
                        ),
                        label: Text(
                          hayPistasDisponibles
                              ? 'Dame una pista (−1 vida)'
                              : 'Sin más pistas disponibles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hayPistasDisponibles
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Campo de texto estricto (número o letra según el modo)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor(context).withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          keyboardType: _esLetra
                              ? TextInputType.text
                              : TextInputType.number,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: _esLetra
                              ? [
                                  FilteringTextInputFormatter.allow(
                                    RegExp('[a-zA-Z]'),
                                  ),
                                  LengthLimitingTextInputFormatter(1),
                                  _UpperCaseTextFormatter(),
                                ]
                              : [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                          textAlign: TextAlign.center,
                          enabled: !_juegoTerminado && !_juegoPerdido,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: _esLetra ? 'Ej. M' : 'Ej. 50',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: scheme.surface,
                            prefixIcon: Icon(
                              _esLetra ? Icons.abc : Icons.pin,
                              color: _accentColor(context),
                            ),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _controller.clear(),
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _verificarAdivinanza(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Botón principal vibrante
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: (_juegoTerminado || _juegoPerdido)
                              ? null
                              : _verificarAdivinanza,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _juegoTerminado
                                ? Colors.green.shade600
                                : (_juegoPerdido
                                      ? Colors.red.shade600
                                      : _accentColor(context)),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 8,
                            shadowColor: _accentColor(context).withOpacity(0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _juegoTerminado
                                    ? Icons.check_circle
                                    : (_juegoPerdido
                                          ? Icons.cancel
                                          : Icons.send_rounded),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _juegoTerminado
                                    ? '¡Ganaste!'
                                    : (_juegoPerdido
                                          ? 'Juego terminado'
                                          : '¡Adivinar!'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Botones de después de terminar
                      if (_juegoTerminado || _juegoPerdido)
                        ScaleTransition(
                          scale: _fadeAnimation,
                          child: Column(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _iniciarJuego,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 15,
                                  ),
                                  backgroundColor: Colors.black.withOpacity(
                                    0.25,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.replay,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Jugar de nuevo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.grid_view,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Cambiar de modo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
