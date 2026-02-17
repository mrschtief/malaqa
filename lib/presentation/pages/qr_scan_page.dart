import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/di/service_locator.dart';
import '../../core/crypto/ed25519_crypto_provider.dart';
import '../../core/interfaces/crypto_provider.dart';
import '../../domain/entities/face_vector.dart';
import '../../domain/entities/meeting_signature_exchange.dart';
import '../../domain/entities/participant_signature.dart';
import '../../domain/repositories/identity_repository.dart';
import '../../domain/services/face_matcher_service.dart';
import '../../domain/services/proof_importer.dart';

enum _ScanUiState {
  scanning,
  success,
  duplicate,
  invalid,
  signatureReady,
}

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const QrScanPage(),
    );
  }

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isImporting = false;
  _ScanUiState _state = _ScanUiState.scanning;
  String _message = 'Scan a meeting QR proof';
  String? _signatureResponsePayload;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isImporting || _state != _ScanUiState.scanning) {
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

    if (raw == null || raw.isEmpty) {
      return;
    }

    _isImporting = true;
    await _scannerController.stop();

    final signaturePayload = await _tryBuildSignatureResponsePayload(raw);
    if (!mounted) {
      return;
    }
    if (signaturePayload != null) {
      setState(() {
        _state = _ScanUiState.signatureReady;
        _signatureResponsePayload = signaturePayload.$1;
        _message = signaturePayload.$2;
      });
      return;
    }

    final importer = getIt<ProofImporter>();
    final result = await importer.importProof(raw);

    if (!mounted) {
      return;
    }

    setState(() {
      switch (result.status) {
        case ImportStatus.success:
          _state = _ScanUiState.success;
          _message = 'Meeting verified via QR';
          break;
        case ImportStatus.duplicate:
          _state = _ScanUiState.duplicate;
          _message = 'Proof already imported on this device.';
          break;
        case ImportStatus.invalid:
          _state = _ScanUiState.invalid;
          _message = 'Ungültiger Proof';
          break;
      }
    });
  }

  Future<void> _scanAgain() async {
    setState(() {
      _state = _ScanUiState.scanning;
      _message = 'Scan a meeting QR proof';
      _isImporting = false;
      _signatureResponsePayload = null;
    });
    await _scannerController.start();
  }

  Future<(String, String)?> _tryBuildSignatureResponsePayload(
      String raw) async {
    final request = MeetingSignRequestEnvelope.tryParseRaw(raw);
    if (request == null) {
      return null;
    }

    final identityRepository = getIt<IdentityRepository>();
    final faceMatcher = getIt<FaceMatcherService>();
    final crypto = getIt<CryptoProvider>();
    final identity = await identityRepository.getIdentity();
    final ownerVector = await identityRepository.getOwnerFaceVector();
    if (identity == null || ownerVector == null) {
      return (
        _rejectPayload(request.requestId, 'not-authenticated'),
        'Keine lokale Identity gefunden. Anfrage wird abgelehnt.',
      );
    }

    final similarity = faceMatcher.compare(
      FaceVector(request.guestVectorValues),
      ownerVector,
    );
    if (similarity < 0.8) {
      return (
        _rejectPayload(request.requestId, 'face-mismatch'),
        'Gesicht passt nicht zur Anfrage. Anfrage wird abgelehnt.',
      );
    }

    if (request.proof.signatures.length != 1) {
      return (
        _rejectPayload(request.requestId, 'invalid-proof-shape'),
        'Anfrage hat ungueltiges Proof-Format.',
      );
    }

    final initiatorSig = request.proof.signatures.first;
    final initiatorValid = await _verifySignature(
      crypto: crypto,
      signature: initiatorSig,
      payload: request.proof.canonicalPayload().codeUnits,
    );
    if (!initiatorValid) {
      return (
        _rejectPayload(request.requestId, 'invalid-initiator-signature'),
        'Anfrage-Signatur ist ungueltig.',
      );
    }

    final signed = await identity.signPayload(
      payload: request.proof.canonicalPayload().codeUnits,
      crypto: crypto,
    );
    final response = MeetingSignResponseEnvelope(
      requestId: request.requestId,
      signature: ParticipantSignature(
        publicKeyHex: identity.publicKeyHex,
        signatureHex: bytesToHex(signed),
      ),
    );
    return (
      jsonEncode(response.toJson()),
      'Signatur erstellt. Partner soll diesen QR jetzt scannen.',
    );
  }

  String _rejectPayload(String requestId, String reason) {
    return jsonEncode(
      MeetingSignRejectEnvelope(
        requestId: requestId,
        reason: reason,
      ).toJson(),
    );
  }

  Future<bool> _verifySignature({
    required CryptoProvider crypto,
    required ParticipantSignature signature,
    required List<int> payload,
  }) async {
    try {
      return crypto.verify(
        message: payload,
        signature: hexToBytes(signature.signatureHex),
        publicKey: hexToBytes(signature.publicKeyHex),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _state != _ScanUiState.scanning;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_state != _ScanUiState.signatureReady)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          if (_state == _ScanUiState.signatureReady &&
              _signatureResponsePayload != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: QrImageView(
                    data: _signatureResponsePayload!,
                    version: QrVersions.auto,
                  ),
                ),
              ),
            ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (hasResult)
            Container(
              color: Colors.black.withValues(alpha: 0.58),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (_state) {
                          _ScanUiState.success => Icons.check_circle_outline,
                          _ScanUiState.duplicate => Icons.info_outline,
                          _ScanUiState.invalid => Icons.error_outline,
                          _ScanUiState.signatureReady => Icons.qr_code_2,
                          _ScanUiState.scanning => Icons.qr_code_scanner,
                        },
                        size: 76,
                        color: switch (_state) {
                          _ScanUiState.success => const Color(0xFF2ECC71),
                          _ScanUiState.duplicate => const Color(0xFF00CFE8),
                          _ScanUiState.invalid => const Color(0xFFE74C3C),
                          _ScanUiState.signatureReady =>
                            const Color(0xFF00CFE8),
                          _ScanUiState.scanning => Colors.white,
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _scanAgain,
                            child: const Text('Scan Again'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
