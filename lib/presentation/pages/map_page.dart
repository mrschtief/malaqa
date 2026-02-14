import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/di/service_locator.dart';
import '../blocs/map/map_cubit.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider<MapCubit>(
        create: (_) => getIt<MapCubit>()..loadMapData(),
        child: const MapPage(),
      ),
    );
  }

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final current = await Geolocator.getCurrentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLocation = LatLng(current.latitude, current.longitude);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
      ),
      body: BlocBuilder<MapCubit, MapState>(
        builder: (context, state) {
          return switch (state) {
            MapLoading _ => const Center(child: CircularProgressIndicator()),
            MapEmpty s => _MapEmptyState(
                message: s.message,
                onReload: () => context.read<MapCubit>().loadMapData(),
              ),
            MapError s => _MapErrorState(
                message: s.message,
                onRetry: () => context.read<MapCubit>().loadMapData(),
              ),
            MapLoaded s => _MapContent(
                mapController: _mapController,
                state: s,
                currentLocation: _currentLocation,
                pulseController: _pulseController,
                onMarkerTap: (marker) => _showMarkerPopup(context, marker),
              ),
          };
        },
      ),
    );
  }

  void _showMarkerPopup(BuildContext context, MapMarkerData marker) {
    final parsedTime = DateTime.tryParse(marker.timestamp)?.toLocal();
    final label = parsedTime == null
        ? marker.timestamp
        : '${parsedTime.year}-${parsedTime.month.toString().padLeft(2, '0')}-${parsedTime.day.toString().padLeft(2, '0')} '
            '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Begegnung #${marker.meetingNumber}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Date: $label'),
              const SizedBox(height: 4),
              Text(
                'Lat ${marker.position.latitude.toStringAsFixed(4)}, '
                'Lon ${marker.position.longitude.toStringAsFixed(4)}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.mapController,
    required this.state,
    required this.currentLocation,
    required this.pulseController,
    required this.onMarkerTap,
  });

  final MapController mapController;
  final MapLoaded state;
  final LatLng? currentLocation;
  final AnimationController pulseController;
  final ValueChanged<MapMarkerData> onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      ...state.markers.map((marker) {
        return Marker(
          width: 44,
          height: 44,
          point: marker.position,
          child: GestureDetector(
            onTap: () => onMarkerTap(marker),
            child: Icon(
              marker.isStart ? Icons.flag_rounded : Icons.place_rounded,
              size: marker.isStart ? 30 : 26,
              color: marker.isStart
                  ? const Color(0xFF00CFE8)
                  : const Color(0xFF009CB0),
            ),
          ),
        );
      }),
    ];

    if (currentLocation != null) {
      markers.add(
        Marker(
          width: 36,
          height: 36,
          point: currentLocation!,
          child: AnimatedBuilder(
            animation: pulseController,
            builder: (_, __) {
              final t = pulseController.value;
              final size = 14 + (8 * t);
              final alpha = 0.25 + (0.2 * (1 - t));
              return Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: alpha),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF27AE60),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final polylines = state.polylines
        .map(
          (path) => Polyline(
            points: path.points,
            strokeWidth: 4,
            color: const Color(0xFF00CFE8).withValues(alpha: 0.55),
          ),
        )
        .toList(growable: false);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: state.centerPoint,
            initialZoom: 3.5,
            minZoom: 2,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.malaqa.app',
              additionalOptions: const {
                'User-Agent': 'malaqa/0.1',
              },
            ),
            if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'recenter-map',
            onPressed: () {
              final target = currentLocation ?? state.centerPoint;
              mapController.move(target, 6);
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({
    required this.message,
    required this.onReload,
  });

  final String message;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Color(0xFF009CB0)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReload,
              child: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapErrorState extends StatelessWidget {
  const _MapErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
