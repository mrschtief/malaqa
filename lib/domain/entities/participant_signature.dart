class ParticipantSignature {
  const ParticipantSignature({
    required this.publicKeyHex,
    required this.signatureHex,
  });

  final String publicKeyHex;
  final String signatureHex;

  String toCanonicalString() => '$publicKeyHex:$signatureHex';
}
