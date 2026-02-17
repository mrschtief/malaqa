import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/face_vector.dart';
import '../../domain/entities/meeting_proof.dart';
import '../../domain/entities/meeting_signature_exchange.dart';
import '../../domain/entities/participant_signature.dart';

class QrSignatureExchangePage extends StatefulWidget {
  const QrSignatureExchangePage({
    super.key,
    required this.draftProof,
    required this.guestVector,
  });

  final MeetingProof draftProof;
  final FaceVector guestVector;

  static Route<ParticipantSignature?> route({
    required MeetingProof draftProof,
    required FaceVector guestVector,
  }) {
    return MaterialPageRoute<ParticipantSignature?>(
      builder: (_) => QrSignatureExchangePage(
        draftProof: draftProof,
        guestVector: guestVector,
      ),
    );
  }

  @override
  State<QrSignatureExchangePage> createState() =>
      _QrSignatureExchangePageState();
}

class _QrSignatureExchangePageState extends State<QrSignatureExchangePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late final String _requestId;
  late final String _requestPayload;
  bool _isScanning = false;
  bool _isProcessingScan = false;
  String _statusMessage =
      '1) Partner scannt den Request-QR. 2) Dann Antwort-QR scannen.';

  @override
  void initState() {
    super.initState();
    final random = Random.secure().nextInt(1 << 32);
    _requestId = '${DateTime.now().microsecondsSinceEpoch}-$random';
    _requestPayload = jsonEncode(
      MeetingSignRequestEnvelope(
        requestId: _requestId,
        proof: widget.draftProof,
        guestVectorValues: widget.guestVector.values,
      ).toJson(),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    await _scannerController.start();
    if (!mounted) {
      return;
    }
    setState(() {
      _isScanning = true;
      _statusMessage = 'Warte auf Antwort-QR vom Partner...';
    });
  }

  Future<void> _stopScanning() async {
    await _scannerController.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessingScan) {
      return;
    }
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) {
      return;
    }

    _isProcessingScan = true;
    try {
      final response = MeetingSignResponseEnvelope.tryParseRaw(raw);
      if (response != null) {
        if (response.requestId != _requestId) {
          if (!mounted) {
            return;
          }
          setState(() {
            _statusMessage = 'Antwort gehoert zu einer anderen Session.';
          });
          return;
        }
        await _stopScanning();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(response.signature);
        return;
      }

      final reject = MeetingSignRejectEnvelope.tryParseRaw(raw);
      if (reject != null) {
        if (reject.requestId == _requestId && mounted) {
          setState(() {
            _statusMessage =
                'Partner hat abgelehnt (${reject.reason}). Erneut probieren.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Unbekannter QR-Inhalt. Bitte Antwort-QR scannen.';
        });
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Signature Fallback'),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isScanning ? _buildScanner() : _buildRequest(),
        ),
      ),
    );
  }

  Widget _buildRequest() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: QrImageView(
                  data: _requestPayload,
                  version: QrVersions.auto,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Antwort-QR scannen'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _stopScanning,
                      child: const Text('Zurueck zum Request-QR'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
