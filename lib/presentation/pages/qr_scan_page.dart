import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/di/service_locator.dart';
import '../../domain/services/proof_importer.dart';

enum _ScanUiState {
  scanning,
  success,
  duplicate,
  invalid,
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
    });
    await _scannerController.start();
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
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
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
                          _ScanUiState.scanning => Icons.qr_code_scanner,
                        },
                        size: 76,
                        color: switch (_state) {
                          _ScanUiState.success => const Color(0xFF2ECC71),
                          _ScanUiState.duplicate => const Color(0xFF00CFE8),
                          _ScanUiState.invalid => const Color(0xFFE74C3C),
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
