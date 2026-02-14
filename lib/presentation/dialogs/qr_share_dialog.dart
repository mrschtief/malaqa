import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/meeting_proof.dart';

class QrShareDialog extends StatelessWidget {
  const QrShareDialog({
    super.key,
    required this.proof,
  });

  final MeetingProof proof;

  @override
  Widget build(BuildContext context) {
    final payload = jsonEncode(proof.toJson());

    return AlertDialog(
      title: const Text('QR Fallback Bridge'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 230,
            height: 230,
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Zeige dies deinem Partner, falls die automatische Verbindung '
            'nicht klappt.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
