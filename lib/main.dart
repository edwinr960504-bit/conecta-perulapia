import 'package:flutter/material.dart';

// === IMPORTS REALES DE TU APLICACIÓN ===
import 'vista_login.dart';
import 'vista_consumidor.dart';
import 'vista_direcciones.dart';
import 'vista_historial.dart';
import 'vista_editar_perfil.dart';

// --- LA LLAVE MAESTRA GLOBAL PARA LA MOTO VERDE ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Atrapa errores para evitar la pantalla roja de Flutter
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  'Algo no salió como esperábamos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(const ConectaApp());
}

class ConectaApp extends StatelessWidget {
  const ConectaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // --- CONECTAMOS LA LLAVE MAESTRA AQUÍ ---
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Conecta Perulapia',

      // ==========================================
      // TEMA VISUAL SOFISTICADO
      // ==========================================
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0055A4), // Azul profesional
          primary: const Color(0xFF0055A4),
          secondary: const Color(0xFF00A896),
          surface: const Color(0xFFF8F9FA),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0055A4), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0055A4),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

      // ==========================================
      // RUTAS (TODAS TUS PANTALLAS CONECTADAS)
      // ==========================================
      initialRoute: '/',
      routes: {
        '/': (context) => const PantallaCargaInicial(),
        '/login': (context) => const LoginPantalla(),
        '/principal': (context) =>
            const VistaConsumidor(nombre: 'Edwin', rol: 'Cliente'),

        '/direcciones': (context) => const VistaDirecciones(),
        '/historial': (context) => const VistaHistorial(),

        // --- AQUÍ CORREGIMOS EL ERROR INYECTANDO EL ID REQUERIDO ---
        '/perfil': (context) => const VistaEditarPerfil(idUsuario: 1),
      },
    );
  }
}

// ==========================================
// PANTALLA DE CARGA INICIAL (SPLASH SCREEN)
// ==========================================
class PantallaCargaInicial extends StatefulWidget {
  const PantallaCargaInicial({super.key});

  @override
  State<PantallaCargaInicial> createState() => _PantallaCargaInicialState();
}

class _PantallaCargaInicialState extends State<PantallaCargaInicial> {
  @override
  void initState() {
    super.initState();
    _arrancarApp();
  }

  Future<void> _arrancarApp() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 24),
            Text(
              'Conecta Perulapia',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0055A4),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sincronizando componentes...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
