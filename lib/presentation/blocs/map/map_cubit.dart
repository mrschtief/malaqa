import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/location_point.dart';
import '../../../domain/entities/meeting_proof.dart';
import '../../../domain/repositories/chain_repository.dart';

class MapMarkerData {
  const MapMarkerData({
    required this.position,
    required this.meetingNumber,
    required this.timestamp,
    required this.isStart,
  });

  final LatLng position;
  final int meetingNumber;
  final String timestamp;
  final bool isStart;
}

class MapPolylineData {
  const MapPolylineData({required this.points});

  final List<LatLng> points;
}

sealed class MapState {
  const MapState();
}

class MapLoading extends MapState {
  const MapLoading();
}

class MapEmpty extends MapState {
  const MapEmpty({this.message = 'No valid map points yet.'});

  final String message;
}

class MapLoaded extends MapState {
  const MapLoaded({
    required this.markers,
    required this.polylines,
    required this.centerPoint,
  });

  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final LatLng centerPoint;
}

class MapError extends MapState {
  const MapError({required this.message});

  final String message;
}

class MapCubit extends Cubit<MapState> {
  MapCubit(this._chainRepository) : super(const MapLoading());

  final ChainRepository _chainRepository;

  Future<void> loadMapData() async {
    emit(const MapLoading());
    try {
      final proofs = await _chainRepository.getAllProofs();
      if (proofs.isEmpty) {
        emit(const MapEmpty(message: 'No meetings found yet.'));
        return;
      }

      final sorted = [...proofs]..sort(_compareByTimestampAsc);

      final validProofs = sorted
          .where((proof) => _isValidCoordinate(proof.location))
          .toList(growable: false);

      if (validProofs.isEmpty) {
        emit(const MapEmpty(message: 'No valid coordinates available yet.'));
        return;
      }

      final points = validProofs
          .map(
            (proof) => LatLng(
              proof.location.latitude,
              proof.location.longitude,
            ),
          )
          .toList(growable: false);

      final markers = <MapMarkerData>[];
      for (var i = 0; i < validProofs.length; i++) {
        markers.add(
          MapMarkerData(
            position: points[i],
            meetingNumber: i + 1,
            timestamp: validProofs[i].timestamp,
            isStart: i == 0,
          ),
        );
      }

      final polylines = points.length >= 2
          ? [MapPolylineData(points: points)]
          : const <MapPolylineData>[];

      emit(
        MapLoaded(
          markers: List<MapMarkerData>.unmodifiable(markers),
          polylines: List<MapPolylineData>.unmodifiable(polylines),
          centerPoint: points.last,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'MAP',
        'Failed to load map data',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const MapError(message: 'Could not load map data.'));
    }
  }

  bool _isValidCoordinate(LocationPoint point) {
    if (point.latitude == 0.0 && point.longitude == 0.0) {
      return false;
    }
    if (point.latitude < -90 || point.latitude > 90) {
      return false;
    }
    if (point.longitude < -180 || point.longitude > 180) {
      return false;
    }
    return true;
  }

  int _compareByTimestampAsc(MeetingProof a, MeetingProof b) {
    final at = DateTime.tryParse(a.timestamp);
    final bt = DateTime.tryParse(b.timestamp);
    if (at == null && bt == null) {
      return a.timestamp.compareTo(b.timestamp);
    }
    if (at == null) {
      return 1;
    }
    if (bt == null) {
      return -1;
    }
    return at.compareTo(bt);
  }
}
