import 'package:crypto/crypto.dart';

/// Thrown for malformed pin values.
class CertificatePinException implements Exception {
  const CertificatePinException(this.message);

  final String message;

  @override
  String toString() => 'CertificatePinException: $message';
}

/// A pinned SHA-256 fingerprint of a DER-encoded X.509 certificate.
///
/// No keys, certificates or fingerprints are embedded in this package. Pins are
/// supplied by the operator/app at runtime, e.g. after an out-of-band PIN
/// confirmation, and stored by the caller.
class CertificatePin {
  CertificatePin._(this.algorithm, this.fingerprintHex);

  final String algorithm;
  final String fingerprintHex;

  factory CertificatePin.fromSha256Hex(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s:]'), '').toLowerCase();
    if (RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized) == false) {
      throw const CertificatePinException(
        'expected 64 hexadecimal characters for a SHA-256 fingerprint',
      );
    }
    return CertificatePin._('sha256', normalized);
  }

  factory CertificatePin.fromDer(List<int> certificateDer) {
    return CertificatePin.fromSha256Hex(sha256.convert(certificateDer).toString());
  }

  bool matchesDer(List<int> certificateDer) =>
      sha256.convert(certificateDer).toString() == fingerprintHex;

  @override
  String toString() => '$algorithm:$fingerprintHex';
}

/// Per-device pin storage used before accepting a TLS connection.
///
/// This is a helper only: wiring it into a `SecureSocket` handshake, trust-on
/// first-use policy and pin rotation are not implemented in this skeleton.
class PinStore {
  final Map<String, Set<CertificatePin>> _pins = <String, Set<CertificatePin>>{};

  void add(String deviceId, CertificatePin pin) {
    _pins.putIfAbsent(deviceId, () => <CertificatePin>{}).add(pin);
  }

  bool hasPins(String deviceId) => (_pins[deviceId]?.isNotEmpty ?? false);

  bool verify(String deviceId, List<int> certificateDer) {
    final pins = _pins[deviceId];
    if (pins == null || pins.isEmpty) {
      return false;
    }
    return pins.any((pin) => pin.matchesDer(certificateDer));
  }

  Set<CertificatePin> pinsFor(String deviceId) =>
      Set<CertificatePin>.unmodifiable(_pins[deviceId] ?? <CertificatePin>{});

  void remove(String deviceId) => _pins.remove(deviceId);
}
