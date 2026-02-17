import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../../core/utils/app_logger.dart';

class NearbyPayloadEvent {
  const NearbyPayloadEvent({
    required this.endpointId,
    required this.payload,
  });

  final String endpointId;
  final String payload;
}

abstract class NearbyService {
  Stream<NearbyPayloadEvent> get payloadStream;

  Future<void> startAdvertising({
    required String userName,
    required String payload,
  });

  Future<void> startDiscovery({
    required String userName,
  });

  Future<void> sendPayload({
    required String endpointId,
    required String payload,
  });

  Future<void> stopAll();
}

class NearbyConnectionsService implements NearbyService {
  NearbyConnectionsService({
    Nearby? nearby,
    this.serviceId = 'com.malaqa.app',
  }) : _nearby = nearby ?? Nearby();

  final Nearby _nearby;
  final String serviceId;

  final StreamController<NearbyPayloadEvent> _payloadController =
      StreamController<NearbyPayloadEvent>.broadcast();

  String? _activeAdvertisedPayload;
  String _userName = 'malaqa';

  @override
  Stream<NearbyPayloadEvent> get payloadStream => _payloadController.stream;

  @override
  Future<void> startAdvertising({
    required String userName,
    required String payload,
  }) async {
    _userName = userName;
    _activeAdvertisedPayload = payload;

    try {
      await _nearby.stopAdvertising();

      final started = await _nearby.startAdvertising(
        userName,
        Strategy.P2P_STAR,
        serviceId: serviceId,
        onConnectionInitiated: (endpointId, connectionInfo) async {
          AppLogger.log(
            'NEARBY',
            'Advertising: connection initiated with $endpointId',
          );
          await _nearby.acceptConnection(
            endpointId,
            onPayLoadRecieved: _onPayloadReceived,
          );
        },
        onConnectionResult: (endpointId, status) async {
          AppLogger.log(
            'NEARBY',
            'Advertising: connection result $status for $endpointId',
          );
          if (status != Status.CONNECTED || _activeAdvertisedPayload == null) {
            return;
          }

          final bytes = Uint8List.fromList(
            utf8.encode(_activeAdvertisedPayload!),
          );
          await _nearby.sendBytesPayload(endpointId, bytes);
          AppLogger.log(
            'NEARBY',
            'Advertising: payload sent to $endpointId',
          );
        },
        onDisconnected: (endpointId) {
          AppLogger.log('NEARBY', 'Advertising: disconnected from $endpointId');
        },
      );

      if (!started) {
        AppLogger.error('NEARBY', 'Failed to start advertising');
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'NEARBY',
        'startAdvertising failed (permissions missing or Nearby unsupported).',
      );
      AppLogger.error(
        'NEARBY',
        'startAdvertising exception',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> startDiscovery({
    required String userName,
  }) async {
    _userName = userName;

    try {
      await _nearby.stopDiscovery();

      final started = await _nearby.startDiscovery(
        userName,
        Strategy.P2P_STAR,
        serviceId: serviceId,
        onEndpointFound: (endpointId, endpointName, discoveredServiceId) async {
          AppLogger.log(
            'NEARBY',
            'Discovery: endpoint found $endpointId ($endpointName)',
          );
          await _nearby.requestConnection(
            _userName,
            endpointId,
            onConnectionInitiated: (requestEndpointId, connectionInfo) async {
              AppLogger.log(
                'NEARBY',
                'Discovery: connection initiated with $requestEndpointId',
              );
              await _nearby.acceptConnection(
                requestEndpointId,
                onPayLoadRecieved: _onPayloadReceived,
              );
            },
            onConnectionResult: (requestEndpointId, status) {
              AppLogger.log(
                'NEARBY',
                'Discovery: connection result $status for $requestEndpointId',
              );
            },
            onDisconnected: (requestEndpointId) {
              AppLogger.log(
                'NEARBY',
                'Discovery: disconnected from $requestEndpointId',
              );
            },
          );
        },
        onEndpointLost: (endpointId) {
          AppLogger.log('NEARBY', 'Discovery: endpoint lost $endpointId');
        },
      );

      if (!started) {
        AppLogger.error('NEARBY', 'Failed to start discovery');
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'NEARBY',
        'startDiscovery failed (permissions missing or Nearby unsupported).',
      );
      AppLogger.error(
        'NEARBY',
        'startDiscovery exception',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) {
      return;
    }
    try {
      final decoded = utf8.decode(payload.bytes!);
      _payloadController.add(
        NearbyPayloadEvent(
          endpointId: endpointId,
          payload: decoded,
        ),
      );
      AppLogger.log(
        'NEARBY',
        'Payload received from $endpointId (${decoded.length} chars)',
      );
    } on FormatException {
      AppLogger.error('NEARBY', 'Received non-UTF8 payload from $endpointId');
    }
  }

  @override
  Future<void> sendPayload({
    required String endpointId,
    required String payload,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(payload));
    await _nearby.sendBytesPayload(endpointId, bytes);
    AppLogger.log('NEARBY', 'Payload sent to $endpointId');
  }

  @override
  Future<void> stopAll() async {
    _activeAdvertisedPayload = null;
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    AppLogger.log('NEARBY', 'Stopped advertising/discovery/endpoints');
  }

  Future<void> dispose() async {
    await stopAll();
    await _payloadController.close();
  }
}
