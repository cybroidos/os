import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'packet.dart';

/// A KDE Connect peer seen on the LAN.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.deviceId,
    required this.name,
    required this.address,
    required this.tcpPort,
    required this.protocolVersion,
  });

  final String deviceId;
  final String name;
  final String address;
  final int tcpPort;
  final int protocolVersion;

  @override
  String toString() =>
      'DiscoveredDevice($deviceId, $name, $address:$tcpPort, v$protocolVersion)';
}

/// LAN discovery surface used by the mobile app.
abstract class DeviceDiscoverer {
  Stream<DiscoveredDevice> get devices;
  Future<void> start();
  Future<void> stop();
}

/// Minimal UDP broadcast discovery compatible with the KDE Connect identity
/// exchange (broadcast to UDP/1716, parse `kdeconnect.identity`).
///
/// This is transport scaffolding only: no response handshake, no deduplication
/// cache, no internet/relay discovery and no KDE Connect interop test yet.
class UdpBroadcastDiscoverer implements DeviceDiscoverer {
  UdpBroadcastDiscoverer({
    required this.deviceId,
    required this.deviceName,
    this.port = 1716,
    this.tcpPort = 1716,
    this.protocolVersion = KdeConnectPacket.protocolVersion,
  });

  final String deviceId;
  final String deviceName;
  final int port;
  final int tcpPort;
  final int protocolVersion;

  final StreamController<DiscoveredDevice> _controller =
      StreamController<DiscoveredDevice>.broadcast();
  RawDatagramSocket? _socket;

  @override
  Stream<DiscoveredDevice> get devices => _controller.stream;

  @override
  Future<void> start() async {
    if (_socket != null) {
      return;
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = socket.receive();
        if (datagram == null) {
          return;
        }
        final device = _parseIdentity(datagram.data, datagram.address.address);
        if (device != null && device.deviceId != deviceId) {
          _controller.add(device);
        }
      },
      onError: _controller.addError,
    );
    _sendIdentity(socket);
  }

  void _sendIdentity(RawDatagramSocket socket) {
    final identity = KdeConnectPacket(
      id: DateTime.now().millisecondsSinceEpoch,
      type: 'kdeconnect.identity',
      body: <String, Object?>{
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceType': 'phone',
        'protocolVersion': protocolVersion,
        'tcpPort': tcpPort,
      },
    );
    try {
      socket.send(
        utf8.encode(identity.encode()),
        InternetAddress('255.255.255.255'),
        port,
      );
    } on SocketException {
      // Some Android networks block broadcast; discovery then finds nothing.
    }
  }

  DiscoveredDevice? _parseIdentity(List<int> bytes, String address) {
    try {
      final packet = KdeConnectPacket.decode(utf8.decode(bytes));
      if (packet.type != 'kdeconnect.identity') {
        return null;
      }
      final id = packet.body['deviceId'];
      final name = packet.body['deviceName'];
      final version = packet.body['protocolVersion'];
      final peerPort = packet.body['tcpPort'];
      if (id is! String || id.isEmpty || name is! String || version is! int || peerPort is! int) {
        return null;
      }
      return DiscoveredDevice(
        deviceId: id,
        name: name,
        address: address,
        tcpPort: peerPort,
        protocolVersion: version,
      );
    } on PacketFormatException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    _socket = null;
    socket.close();
    await _controller.close();
  }
}

/// Placeholder for mDNS discovery of `_kdeconnect._udp`.
///
/// Not implemented in 0.1.0; calling [start] throws [UnimplementedError].
class MdnsDeviceDiscoverer implements DeviceDiscoverer {
  @override
  Stream<DiscoveredDevice> get devices => const Stream<DiscoveredDevice>.empty();

  @override
  Future<void> start() async {
    throw UnimplementedError('mDNS discovery is not implemented in cybroidos_connect 0.1.0');
  }

  @override
  Future<void> stop() async {}
}
