import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MapaTileLayer extends StatelessWidget {
  const MapaTileLayer({super.key});

  static final Future<FileCacheStore> _cacheStore = _crearCacheStore();

  static Future<FileCacheStore> _crearCacheStore() async {
    final directory = await getApplicationCacheDirectory();
    return FileCacheStore(
      '${directory.path}${Platform.pathSeparator}map_tiles',
    );
  }

  TileLayer _crearCapa({FileCacheStore? cacheStore}) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.perulapia_connect',
      tileProvider: cacheStore == null
          ? NetworkTileProvider()
          : CachedTileProvider(
              store: cacheStore,
              maxStale: const Duration(days: 30),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FileCacheStore>(
      future: _cacheStore,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
              'No se pudo inicializar la caché de mapas: ${snapshot.error}');
          return _crearCapa();
        }
        return _crearCapa(cacheStore: snapshot.data);
      },
    );
  }
}

class MapaAtribucion extends StatelessWidget {
  const MapaAtribucion({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          '© OpenStreetMap contributors',
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
          ),
        ),
      ],
    );
  }
}

class MapaPosicionAnimator {
  Timer? _timer;

  void animar({
    required LatLng desde,
    required LatLng hasta,
    required ValueChanged<LatLng> alActualizar,
    Duration duracion = const Duration(milliseconds: 2400),
  }) {
    _timer?.cancel();
    const Distance distancia = Distance();
    if (distancia.as(LengthUnit.Meter, desde, hasta) < 2 ||
        duracion.inMilliseconds <= 0) {
      alActualizar(hasta);
      return;
    }
    final reloj = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      final double progreso =
          (reloj.elapsedMilliseconds / duracion.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
      alActualizar(
        LatLng(
          desde.latitude + (hasta.latitude - desde.latitude) * progreso,
          desde.longitude + (hasta.longitude - desde.longitude) * progreso,
        ),
      );
      if (progreso >= 1.0) timer.cancel();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

Widget mapaPinVisual({
  required IconData icon,
  required Color color,
  required double size,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: const [
        BoxShadow(
          color: Colors.black38,
          blurRadius: 7,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.52),
  );
}
