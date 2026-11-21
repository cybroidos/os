import 'packet.dart';

/// KDE Connect pairing states, kept deliberately explicit.
enum PairingState { idle, requested, awaitingPin, verifying, paired, failed }

/// Transport hook for the pairing exchange; implemented by the future TLS layer.
abstract class PairingTransport {
  Future<void> sendPairRequest({
    required String deviceId,
    required String deviceName,
  });

  Future<void> sendPin({required String deviceId, required String pin});
}

/// PIN + key-exchange flow interface.
///
/// v0 only builds/validates packets and tracks state. It does not perform key
/// exchange, TOFU certificate acceptance or peer verification.
class PairingSession {
  PairingSession({
    required this.deviceId,
    required this.deviceName,
    required this.transport,
    this.pinLength = 6,
  }) : state = PairingState.idle;

  final String deviceId;
  final String deviceName;
  final PairingTransport transport;
  final int pinLength;

  PairingState state;

  Future<void> requestPairing() async {
    if (state != PairingState.idle) {
      throw StateError('pairing already started: $state');
    }
    state = PairingState.requested;
    await transport.sendPairRequest(deviceId: deviceId, deviceName: deviceName);
    state = PairingState.awaitingPin;
  }

  /// Send a numeric PIN. The peer's acceptance must be observed separately via
  /// [confirmPaired] or [reject]; this method never claims success on its own.
  Future<void> submitPin(String pin) async {
    if (state != PairingState.awaitingPin) {
      throw StateError('not waiting for a PIN: $state');
    }
    if (RegExp(r'^\d{' + pinLength.toString() + r'}$').hasMatch(pin) == false) {
      state = PairingState.failed;
      throw ArgumentError.value(pin, 'pin', 'expected $pinLength digits');
    }
    state = PairingState.verifying;
    await transport.sendPin(deviceId: deviceId, pin: pin);
  }

  void confirmPaired() {
    if (state != PairingState.verifying) {
      throw StateError('no PIN verification in progress: $state');
    }
    state = PairingState.paired;
  }

  void reject() => state = PairingState.failed;

  /// KDE Connect pair-request packet.
  KdeConnectPacket buildPairRequest() => KdeConnectPacket(
        id: DateTime.now().millisecondsSinceEpoch,
        type: 'kdeconnect.pair',
        body: <String, Object?>{'pair': true},
      );

  /// KDE Connect pair response carrying the numeric PIN.
  KdeConnectPacket buildPinPacket(String pin) => KdeConnectPacket(
        id: DateTime.now().millisecondsSinceEpoch,
        type: 'kdeconnect.pair',
        body: <String, Object?>{'pin': pin},
      );
}
