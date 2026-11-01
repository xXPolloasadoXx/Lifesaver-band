import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Instancia global para las notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración inicial de notificaciones locales para Android
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Inicializar el servicio en segundo plano
  await initializeBackgroundService();

  runApp(const AlertaBleApp());
}

// Configuración del servicio en segundo plano
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alerta_ble_bg_channel',
    'Servicio Alerta SOS Segundo Plano',
    description: 'Mantiene la conexión BLE activa con el ESP32',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackgroundService,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'alerta_ble_bg_channel',
      initialNotificationTitle: 'Alerta SOS Activa',
      initialNotificationContent: 'Monitoreando dispositivo ESP32 en segundo plano...',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartBackgroundService,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Escuchar datos enviados desde la UI principal cuando el ESP32 emita la señal en segundo plano
  service.on('enviarAlertaBackground').listen((event) async {
    List<dynamic> receptores = event?['receptores'] ?? [];
    if (receptores.isEmpty) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String googleMapsUrl =
          "https://maps.google.com/?q=${position.latitude.toStringAsFixed(7)},${position.longitude.toStringAsFixed(7)}";
      String mensajeSOS =
          "¡EMERGENCIA! Necesito ayuda urgente (En segundo plano). Mi ubicación: $googleMapsUrl";

      for (var numero in receptores) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: numero.toString(),
          queryParameters: {'body': mensajeSOS},
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print("Error enviando SMS en segundo plano: $e");
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

class AlertaBleApp extends StatelessWidget {
  const AlertaBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alerta SOS BLE',
      theme: ThemeData(
        primaryColor: const Color(0xFF800020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF800020),
          primary: const Color(0xFF800020),
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// =================================================================
// 1. PANTALLA DE SELECCIÓN DE MODO (INICIO / REVERSIBLE)
// =================================================================
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selección de Modo - Alerta SOS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF800020),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_rounded, size: 80, color: Color(0xFF800020)),
            const SizedBox(height: 20),
            const Text(
              'Selecciona tu Modo de Usuario',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              'Elige cómo operará este dispositivo en la red de emergencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800020),
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EmisorScreen()),
                );
              },
              icon: const Icon(Icons.sensors, color: Colors.white, size: 28),
              label: const Text('MODO EMISOR (Dispositivo / Pulsera)', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF800020), width: 2),
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ReceptorScreen()),
                );
              },
              icon: const Icon(Icons.phone_android, color: Color(0xFF800020), size: 28),
              label: const Text('MODO RECEPTOR (Contacto de Apoyo)', style: TextStyle(color: Color(0xFF800020), fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 2. MODO EMISOR (Conexión ESP32-C3, Nombre BT y Envío automático SMS)
// =================================================================
class EmisorScreen extends StatefulWidget {
  const EmisorScreen({super.key});

  @override
  State<EmisorScreen> createState() => _EmisorScreenState();
}

class _EmisorScreenState extends State<EmisorScreen> {
  BluetoothDevice? connectedDevice;
  bool isScanning = false;
  List<String> receptoresList = [];
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _btNameController = TextEditingController();
  String currentBtName = "AlertaEmisor_BLE";

  final Telephony _telephony = Telephony.instance;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  @override
  void initState() {
    super.initState();
    _pedirPermisosIniciales();
  }

  Future<void> _pedirPermisosIniciales() async {
    await _telephony.requestSmsPermissions;
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _btNameController.dispose();
    _scanSub?.cancel();
    _notifySub?.cancel();
    super.dispose();
  }

  void _agregarReceptor() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        receptoresList.add(_phoneController.text);
        _phoneController.clear();
      });
    }
  }

  void _cambiarNombreBluetooth() {
    if (_btNameController.text.isNotEmpty) {
      setState(() {
        currentBtName = _btNameController.text;
        _btNameController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nombre Bluetooth actualizado a: $currentBtName'), backgroundColor: Colors.green),
      );
    }
  }

  void _iniciarEscaneo() async {
    setState(() => isScanning = true);
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      print("Error escaneando: $e");
    }
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => isScanning = scanning);
    });
  }

  void _conectarESP32(BluetoothDevice device) async {
    try {
      await device.connect();
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();

      setState(() {
        connectedDevice = device;
        isScanning = false;
      });

      // Iniciar el servicio en segundo plano al conectar exitosamente
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Conectado! Servicio en segundo plano activo 🚀'), backgroundColor: Colors.green),
        );
      }

      List<BluetoothService> services = await device.discoverServices();
      for (var serviceBle in services) {
        for (var characteristic in serviceBle.characteristics) {
          if (characteristic.properties.notify || characteristic.properties.read) {
            await characteristic.setNotifyValue(true);
            _notifySub = characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                if (value.contains(65) || value.contains(0x41)) {
                  _dispararAlertaSOSAutomatico();
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print("Error conectando: $e");
    }
  }

  Future<void> _dispararAlertaSOSAutomatico() async {
    try {
      if (receptoresList.isEmpty) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String googleMapsUrl =
          "https://maps.google.com/?q=${position.latitude.toStringAsFixed(7)},${position.longitude.toStringAsFixed(7)}";
      String mensajeSOS =
          "¡EMERGENCIA! Necesito ayuda urgente. Mi ubicación: $googleMapsUrl";

      // Envío directo utilizando el protocolo nativo a través de url_launcher (evita fallos de SmsManager)
      for (String numero in receptoresList) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: numero,
          queryParameters: {'body': mensajeSOS},
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        }
      }

      // Notificar también al servicio en segundo plano por si la app se encuentra minimizada
      final service = FlutterBackgroundService();
      service.invoke('enviarAlertaBackground', {'receptores': receptoresList});

      if (mounted) {
        showDialog(
          context: this.context,
          builder: (context) => AlertDialog(
            title: const Text('¡ALERTA SOS DISPARADA!', style: TextStyle(color: Color(0xFF800020), fontWeight: FontWeight.bold)),
            content: Text('Se recibió la señal 0x41 del ESP32.\nUbicación preparada para ${receptoresList.length} contactos.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar', style: TextStyle(color: Color(0xFF800020))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("Error al disparar SOS automático: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Emisor (Dispositivo SOS)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF800020),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            final service = FlutterBackgroundService();
            if (await service.isRunning()) {
              service.invoke("stopService");
            }
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
              );
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nombre Bluetooth Actual: $currentBtName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF800020))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _btNameController,
                            decoration: const InputDecoration(
                              hintText: 'Nuevo nombre Bluetooth',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                          onPressed: _cambiarNombreBluetooth,
                          child: const Text('Cambiar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agregar Números de Receptores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Ej. +528711234567',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                          onPressed: _agregarReceptor,
                          child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: receptoresList.map((num) => Chip(
                        label: Text(num),
                        backgroundColor: Colors.red[50],
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => receptoresList.remove(num)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (connectedDevice != null) ...[
              Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected, color: Color(0xFF800020), size: 32),
                  title: Text('ESP32 Conectado: ${connectedDevice!.platformName.isNotEmpty ? connectedDevice!.platformName : "SuperMini"}'),
                  subtitle: Text('ID: ${connectedDevice!.remoteId}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () async {
                      await connectedDevice!.disconnect();
                      setState(() => connectedDevice = null);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _dispararAlertaSOSAutomatico,
                icon: const Icon(Icons.warning, color: Colors.white),
                label: const Text('SIMULAR ALERTA SOS AUTOMÁTICA', style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800020),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: isScanning ? null : _iniciarEscaneo,
                icon: const Icon(Icons.search, color: Colors.white),
                label: Text(isScanning ? 'Buscando ESP32-C3...' : 'Buscar ESP32-C3 SuperMini', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Presiona buscar para emparejar tu ESP32.'));
                    }
                    final results = snapshot.data!;
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final data = results[index];
                        return Card(
                          child: ListTile(
                            title: Text(data.device.platformName.isNotEmpty ? data.device.platformName : "Dispositivo Desconocido"),
                            subtitle: Text(data.device.remoteId.toString()),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                              child: const Text('Conectar', style: TextStyle(color: Colors.white)),
                              onPressed: () => _conectarESP32(data.device),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =================================================================
// 3. MODO RECEPTOR (Con Notificaciones en App y Bandeja del Celular)
// =================================================================
class ReceptorScreen extends StatefulWidget {
  const ReceptorScreen({super.key});

  @override
  State<ReceptorScreen> createState() => _ReceptorScreenState();
}

class _ReceptorScreenState extends State<ReceptorScreen> {
  final TextEditingController _emisorController = TextEditingController();
  String? emisorAsociado;
  final List<String> _historialAlertas = [];

  @override
  void dispose() {
    _emisorController.dispose();
    super.dispose();
  }

  void _guardarEmisor() {
    if (_emisorController.text.isNotEmpty) {
      setState(() {
        emisorAsociado = _emisorController.text;
        _emisorController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emisor enlazado correctamente al receptor.'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _simularRecepcionAlerta() async {
    String alertaTexto = "¡Alerta de emergencia recibida del emisor $emisorAsociado!";

    setState(() {
      _historialAlertas.insert(0, alertaTexto);
    });

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'canal_emergencia_sos',
      'Alertas SOS',
      channelDescription: 'Canal para notificaciones de emergencia',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFF800020),
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      '🚨 ¡EMERGENCIA SOS!',
      'Pulsa para ver la ubicación del emisor.',
      platformChannelSpecifics,
      payload: 'item x',
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¡Alerta Recibida!', style: TextStyle(color: Color(0xFF800020), fontWeight: FontWeight.bold)),
          content: Text(alertaTexto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Color(0xFF800020))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Receptor (Apoyo)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF800020),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configurar Emisor de Confianza',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF800020)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emisorController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Número de teléfono del Emisor',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800020)),
                  onPressed: _guardarEmisor,
                  child: const Text('Vincular', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (emisorAsociado != null) ...[
              Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.person_pin, color: Color(0xFF800020), size: 32),
                  title: Text('Monitoreando al Emisor: $emisorAsociado'),
                  subtitle: const Text('Escuchando notificaciones de emergencia...'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => emisorAsociado = null),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  minimumSize: const Size.fromHeight(45),
                ),
                onPressed: _simularRecepcionAlerta,
                icon: const Icon(Icons.notification_important, color: Colors.white),
                label: const Text('SIMULAR ENTRADA DE ALERTA', style: TextStyle(color: Colors.white)),
              ),
            ],
            const Divider(height: 30),
            const Text(
              'Bandeja de Alertas Recibidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _historialAlertas.isEmpty
                  ? const Center(
                child: Text(
                  'No hay alertas de emergencia activas.\nLas notificaciones aparecerán aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _historialAlertas.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.red[50],
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFF800020)),
                      title: Text(_historialAlertas[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Recibido vía SMS / Red de Alerta'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}