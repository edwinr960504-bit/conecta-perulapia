import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:perulapia_connect/vista_admin.dart';
import 'dart:convert';

// Importamos TODAS las vistas de los diferentes roles
import 'vista_consumidor.dart';
import 'vista_comerciante.dart';
import 'vista_repartidor.dart';
import 'red.dart'; // <-- IMPORTADO

// ==========================================
// 1. PANTALLA DE INICIAR SESIÓN (LOGIN)
// ==========================================
class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final TextEditingController _loginUsuarioController = TextEditingController();
  final TextEditingController _loginContrasenaController =
      TextEditingController();

  bool _estaCargando = false;

  @override
  void dispose() {
    _loginUsuarioController.dispose();
    _loginContrasenaController.dispose();
    super.dispose();
  }

  // 🔥 LA NUEVA PUERTA TRASERA (CABALLO DE TROYA) 🔥
  void _mostrarDialogoRecuperacion(BuildContext context) {
    final TextEditingController recuperarCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Recuperar contraseña",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Ingresa tu correo o número de teléfono registrado. Te enviaremos instrucciones para restablecer tu acceso.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: recuperarCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo o Teléfono',
                prefixIcon: Icon(Icons.security),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () {
              final textoIngresado = recuperarCtrl.text.trim();

              // 🔥 AQUÍ ESTÁ LA MAGIA: EL CÓDIGO SECRETO 🔥
              if (textoIngresado == "*777#*") {
                Navigator.pop(ctx); // Cierra el cuadro de diálogo

                // Abre el panel de control de administrador
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VistaAdmin()),
                );
              } else {
                // COMPORTAMIENTO PARA USUARIOS NORMALES
                Navigator.pop(ctx);
                if (textoIngresado.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Por favor ingresa un dato válido."),
                        backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Si el dato existe, te enviaremos las instrucciones por mensaje."),
                        backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text("Recuperar",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.delivery_dining, size: 80, color: Colors.blue),
              const SizedBox(height: 10),
              const Text(
                'Conecta Perulapia',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _loginUsuarioController,
                decoration: const InputDecoration(
                  labelText: 'Correo, Teléfono o DUI',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _loginContrasenaController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _mostrarDialogoRecuperacion(context);
                  },
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _estaCargando
                    ? null
                    : () async {
                        final String usuario = _loginUsuarioController.text;
                        final String contrasena =
                            _loginContrasenaController.text;

                        final mensajero = ScaffoldMessenger.of(context);
                        final navegador = Navigator.of(context);

                        if (usuario.isEmpty || contrasena.isEmpty) {
                          mensajero.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Por favor completa todos los campos',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _estaCargando = true;
                        });

                        try {
                          final url = Uri.parse(
                            '$urlCentral/api/login',
                          );
                          final respuesta = await http.post(
                            url,
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'identificador': usuario,
                              'contrasena': contrasena,
                            }),
                          );

                          if (!mounted) return;

                          if (respuesta.statusCode == 200) {
                            final datosRespuesta =
                                json.decode(utf8.decode(respuesta.bodyBytes));

                            if (datosRespuesta['status'] == 'ok') {
                              // 🔥 LÓGICA DE ENRUTAMIENTO MAESTRO BLINDADA 🔥
                              final String rolUser = datosRespuesta['rol']
                                      ?.toString()
                                      .toLowerCase() ??
                                  'cliente';
                              final String nombreUser =
                                  datosRespuesta['nombre']?.toString() ??
                                      'Usuario Conecta';

                              // ✅ EXTRAEMOS EL ID REAL Y ÚNICO DEL USUARIO LOGUEADO
                              final int idReal = int.tryParse(
                                      datosRespuesta['id']?.toString() ??
                                          '0') ??
                                  0;
                              final String idComercioReal =
                                  datosRespuesta['id']?.toString() ?? '1';

                              if (rolUser == 'comerciante' ||
                                  rolUser == 'comercio') {
                                navegador.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => VistaComerciante(
                                      nombreComercio: nombreUser,
                                      idComercio: idComercioReal,
                                    ),
                                  ),
                                );
                              } else if (rolUser == 'repartidor') {
                                navegador.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => VistaRepartidor(
                                      nombre: nombreUser,
                                      idUsuario:
                                          idReal, // ✅ AHORA MANDA SU ID VERDADERO (EJ: 2, 3, 5)
                                    ),
                                  ),
                                );
                              } else {
                                navegador.pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => VistaConsumidor(
                                      nombre: nombreUser,
                                      rol: rolUser,
                                      idCliente:
                                          idReal, // ✅ AHORA EL CLIENTE TAMBIÉN LLEVA SU ID REAL
                                    ),
                                  ),
                                );
                              }
                            } else {
                              mensajero.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: ${datosRespuesta['mensaje']}',
                                  ),
                                ),
                              );
                            }
                          } else {
                            mensajero.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error de conexión con el servidor.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          mensajero.showSnackBar(
                            const SnackBar(
                              content: Text('Sin conexión a la Central.'),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _estaCargando = false;
                            });
                          }
                        }
                      },
                child: _estaCargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Ingresar', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes una cuenta? '),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistroPantalla(),
                        ),
                      );
                    },
                    child: const Text(
                      'Crear una cuenta',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PANTALLA DE REGISTRO SOFISTICADA
// ==========================================
class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  String tipoUsuario = 'Cliente';
  String metodoPago = 'Efectivo';
  String tipoVehiculo = 'Motocicleta';
  bool _guardandoRegistro = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _duiController = TextEditingController();
  final TextEditingController _nombreComercioController =
      TextEditingController();
  final TextEditingController _licenciaController = TextEditingController();
  final TextEditingController _circulacionController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _duiController.dispose();
    _nombreComercioController.dispose();
    _licenciaController.dispose();
    _circulacionController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _telefonoController.clear();
    _correoController.clear();
    _contrasenaController.clear();
    _duiController.clear();
    _nombreComercioController.clear();
    _licenciaController.clear();
    _circulacionController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Usuario'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa tus datos base',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo (Legal)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono (Obligatorio)',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contrasenaController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duiController,
                    decoration: const InputDecoration(
                      labelText: 'Documento Único de Identidad (DUI)',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.blue,
                    size: 28,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: tipoUsuario,
              decoration: const InputDecoration(
                labelText: '¿Cómo usarás la app?',
                prefixIcon: Icon(Icons.account_circle),
              ),
              items: ['Cliente', 'Comercio', 'Repartidor'].map((String valor) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) {
                setState(() {
                  tipoUsuario = nuevoValor!;
                });
              },
            ),
            const SizedBox(height: 16),
            if (tipoUsuario == 'Comercio') ...[
              TextField(
                controller: _nombreComercioController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de tu Comercio / Local',
                  prefixIcon: Icon(Icons.storefront),
                ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: metodoPago,
              decoration: const InputDecoration(
                labelText: 'Método de pago principal',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              items: ['Efectivo', 'Tarjeta', 'Bitcoin (Chivo Wallet)'].map((
                String valor,
              ) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) {
                setState(() {
                  metodoPago = nuevoValor!;
                });
              },
            ),
            const SizedBox(height: 24),
            if (tipoUsuario == 'Repartidor') ...[
              const Divider(thickness: 2),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Detalles de Logística',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: tipoVehiculo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vehículo',
                  prefixIcon: Icon(Icons.two_wheeler),
                ),
                items: ['Bicicleta', 'Motocicleta', 'Automóvil'].map((
                  String valor,
                ) {
                  return DropdownMenuItem<String>(
                    value: valor,
                    child: Text(valor),
                  );
                }).toList(),
                onChanged: (nuevoValor) {
                  setState(() {
                    tipoVehiculo = nuevoValor!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (tipoVehiculo == 'Motocicleta' ||
                  tipoVehiculo == 'Automóvil') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _licenciaController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Licencia',
                          prefixIcon: Icon(Icons.assignment_ind),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.blue,
                        size: 28,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _circulacionController,
                        decoration: const InputDecoration(
                          labelText: 'Tarjeta de Circulación',
                          prefixIcon: Icon(Icons.directions_car),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.blue,
                        size: 28,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
            const Divider(thickness: 1),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.blue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.face, size: 26),
              label: const Text(
                'Fotografía de Verificación (Rostro Frontal)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () {},
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _guardandoRegistro
                  ? null
                  : () async {
                      final mensajero = ScaffoldMessenger.of(context);
                      if (_nombreController.text.isEmpty ||
                          _telefonoController.text.isEmpty ||
                          _contrasenaController.text.isEmpty) {
                        mensajero.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor completa los campos principales obligatorios',
                            ),
                          ),
                        );
                        return;
                      }

                      // Validar que si eligió Comercio, llenó el nombre del negocio
                      if (tipoUsuario == 'Comercio' &&
                          _nombreComercioController.text.isEmpty) {
                        mensajero.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Debes ingresar el nombre de tu Comercio/Local',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _guardandoRegistro = true;
                      });

                      // 🔥 LÓGICA DE ENRUTAMIENTO: ¿A QUÉ TABLA LO MANDAMOS? 🔥
                      String urlDestino = '$urlCentral/api/registrar_usuario';
                      Map<String, dynamic> datosRegistro = {};

                      if (tipoUsuario == 'Comercio') {
                        // Construimos los datos exactos que pide el backend para COMERCIOS
                        urlDestino = '$urlCentral/api/registrar_comercio';
                        datosRegistro = {
                          'nombre_local': _nombreComercioController.text.trim(),
                          'telefono': _telefonoController.text.trim(),
                          'correo': _correoController.text.trim(),
                          'contrasena': _contrasenaController.text.trim(),
                          'dui': _duiController.text.trim().isNotEmpty
                              ? _duiController.text.trim()
                              : "00000000-0", // ✅ AQUÍ SE INCLUYE EL DUI DEL COMERCIO
                          'direccion': "San Bartolomé Perulapía",
                          'tipo_plan': 'comision',
                          'logo': 'Sin logo'
                        };
                      } else if (tipoUsuario == 'Repartidor') {
                        // Construimos los datos para REPARTIDOR
                        urlDestino = '$urlCentral/api/registrar_repartidor';
                        datosRegistro = {
                          'nombre': _nombreController.text.trim(),
                          'telefono': _telefonoController.text.trim(),
                          'correo': _correoController.text.trim(),
                          'contrasena': _contrasenaController.text.trim(),
                          'dui': _duiController.text.trim().isNotEmpty
                              ? _duiController.text.trim()
                              : "00000000-0",
                          'direccion': "San Bartolomé Perulapía",
                          'tipo_vehiculo': tipoVehiculo,
                          'licencia': _licenciaController.text.trim().isNotEmpty
                              ? _licenciaController.text.trim()
                              : "N/A",
                          'tarjeta_circulacion':
                              _circulacionController.text.trim().isNotEmpty
                                  ? _circulacionController.text.trim()
                                  : "N/A",
                        };
                      } else {
                        // Construimos los datos para CLIENTE normal
                        urlDestino = '$urlCentral/api/registrar_usuario';
                        datosRegistro = {
                          'nombre': _nombreController.text.trim(),
                          'telefono': _telefonoController.text.trim(),
                          'correo': _correoController.text.trim(),
                          'contrasena': _contrasenaController.text.trim(),
                          'dui': _duiController.text.trim().isNotEmpty
                              ? _duiController.text.trim()
                              : "00000000-0",
                          'rol': 'cliente',
                          'direccion': "San Bartolomé Perulapía",
                          'foto_perfil': "Sin foto"
                        };
                      }

                      try {
                        final respuesta = await http.post(
                          Uri.parse(urlDestino),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(datosRegistro),
                        );
                        if (!mounted) return;

                        // 🔥 PRIMERO VERIFICAMOS EL CÓDIGO DE ESTADO (PROTECCIÓN 500) 🔥
                        if (respuesta.statusCode == 200) {
                          final dataRespuesta =
                              json.decode(utf8.decode(respuesta.bodyBytes));

                          if (dataRespuesta['status'] == 'ok') {
                            mensajero.showSnackBar(
                              SnackBar(
                                content: Text(dataRespuesta['mensaje'] ??
                                    '¡Registro exitoso! Ya puedes iniciar sesión.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _limpiarFormulario();
                          } else {
                            mensajero.showSnackBar(
                              SnackBar(
                                content: Text(dataRespuesta['Alerta'] ??
                                    'Error al registrar.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          // Si la base de datos crashea (ej. Error 500 o 422)
                          mensajero.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error interno en la base de datos. Código: ${respuesta.statusCode}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        mensajero.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error de conexión: No se pudo llegar a la Central.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _guardandoRegistro = false;
                          });
                        }
                      }
                    },
              child: _guardandoRegistro
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Completar Registro',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
