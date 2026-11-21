import 'dart:convert';

import 'package:cybroidos_connect/cybroidos_connect.dart';
import 'package:test/test.dart';

void main() {
  group('KdeConnectPacket', () {
    test('targets KDE Connect protocol v8', () {
      expect(KdeConnectPacket.protocolVersion, 8);
    });

    test('encodes a newline-terminated v8 envelope and round-trips', () {
      final packet = KdeConnectPacket(
        id: 42,
        type: 'cybroidos.action',
        body: <String, Object?>{'action': 'lock'},
      );

      final encoded = packet.encode();
      expect(encoded, endsWith('\n'));

      final json = jsonDecode(encoded.trim()) as Map<String, dynamic>;
      expect(json['id'], 42);
      expect(json['type'], 'cybroidos.action');
      expect(json['body'], <String, dynamic>{'action': 'lock'});
      expect(json.containsKey('payloadSize'), isFalse);

      final decoded = KdeConnectPacket.decode(encoded);
      expect(decoded.id, 42);
      expect(decoded.type, packet.type);
      expect(decoded.body['action'], 'lock');
      expect(decoded.payloadSize, isNull);
    });

    test('preserves optional payload metadata', () {
      final packet = KdeConnectPacket(
        id: 'packet-7',
        type: 'kdeconnect.file',
        body: <String, Object?>{'filename': 'photo.jpg'},
        payloadSize: 1024,
        payloadTransferInfo: <String, Object?>{'port': 1739},
      );

      final decoded = KdeConnectPacket.decode(packet.encode());
      expect(decoded.id, 'packet-7');
      expect(decoded.payloadSize, 1024);
      expect(decoded.payloadTransferInfo?['port'], 1739);
    });

    test('rejects malformed envelopes', () {
      expect(
        () => KdeConnectPacket.decode('not json'),
        throwsA(isA<PacketFormatException>()),
      );
      expect(
        () => KdeConnectPacket.decode('{"id":1,"body":{}}'),
        throwsA(isA<PacketFormatException>()),
      );
      expect(
        () => KdeConnectPacket.decode('{"id":1,"type":"x","body":[]}'),
        throwsA(isA<PacketFormatException>()),
      );
      expect(
        () => KdeConnectPacket.decode('{"id":1,"type":"x","body":{},"payloadSize":"large"}'),
        throwsA(isA<PacketFormatException>()),
      );
    });

    test('decodeStream yields complete packets only', () {
      final first = KdeConnectPacket(id: 1, type: 't.one', body: const <String, Object?>{});
      final second = KdeConnectPacket(
        id: 2,
        type: 't.two',
        body: <String, Object?>{'value': 2},
      );
      final chunk = '${first.encode()}${second.encode()}{"id":3,"type":"t.three"';

      final decoded = KdeConnectPacket.decodeStream(chunk).toList();
      expect(decoded, hasLength(2));
      expect(decoded.map((packet) => packet.type), <String>['t.one', 't.two']);
    });
  });
}
