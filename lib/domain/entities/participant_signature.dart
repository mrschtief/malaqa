class ParticipantSignature {
  const ParticipantSignature({
    required this.publicKeyHex,
    required this.signatureHex,
  });

  final String publicKeyHex;
  final String signatureHex;

  Map<String, String> toJson() {
    return {
      'publicKeyHex': publicKeyHex,
      'signatureHex': signatureHex,
    };
  }

  factory ParticipantSignature.fromJson(Map<String, dynamic> json) {
    return ParticipantSignature(
      publicKeyHex: json['publicKeyHex'] as String,
      signatureHex: json['signatureHex'] as String,
    );
  }

  String toCanonicalString() => '$publicKeyHex:$signatureHex';
}
