import 'dart:convert';

/// Thrown when a packet is malformed or fails validation.
class PacketFormatException implements Exception {
  const PacketFormatException(this.message);

  final String message;

  @override
  String toString() => 'PacketFormatException: $message';
}

/// A KDE Connect protocol v8 network packet.
///
/// Wire form is a newline-terminated JSON object with `id`, `type` and `body`,
/// plus optional `payloadSize` and `payloadTransferInfo` for file transfers.
class KdeConnectPacket {
  KdeConnectPacket({
    required this.id,
    required this.type,
    Map<String, Object?>? body,
    this.payloadSize,
    this.payloadTransferInfo,
  }) : body = Map<String, Object?>.unmodifiable(body ?? const <String, Object?>{});

  /// KDE Connect protocol version targeted by this skeleton.
  static const int protocolVersion = 8;

  /// Packet id as received: an int or a non-empty String.
  final Object id;
  final String type;
  final Map<String, Object?> body;
  final int? payloadSize;
  final Map<String, Object?>? payloadTransferInfo;

  factory KdeConnectPacket.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! int && (id is! String || id.isEmpty)) {
      throw const PacketFormatException('id must be an int or non-empty String');
    }

    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw const PacketFormatException('type must be a non-empty String');
    }

    final rawBody = json['body'];
    if (rawBody is! Map) {
      throw const PacketFormatException('body must be a JSON object');
    }
    final body = _stringKeyedMap(rawBody, 'body');

    final payloadSize = json['payloadSize'];
    if (payloadSize != null && payloadSize is! int) {
      throw const PacketFormatException('payloadSize must be an int');
    }

    Map<String, Object?>? payloadTransferInfo;
    final rawTransferInfo = json['payloadTransferInfo'];
    if (rawTransferInfo != null) {
      if (rawTransferInfo is! Map) {
        throw const PacketFormatException('payloadTransferInfo must be an object');
      }
      payloadTransferInfo = _stringKeyedMap(rawTransferInfo, 'payloadTransferInfo');
    }

    return KdeConnectPacket(
      id: id,
      type: type,
      body: body,
      payloadSize: payloadSize,
      payloadTransferInfo: payloadTransferInfo,
    );
  }

  Map<String, Object?> toJson() {
    final result = <String, Object?>{'id': id, 'type': type, 'body': body};
    if (payloadSize != null) {
      result['payloadSize'] = payloadSize;
    }
    if (payloadTransferInfo != null) {
      result['payloadTransferInfo'] = payloadTransferInfo;
    }
    return result;
  }

  /// Encode as one newline-terminated JSON line.
  String encode() => '${jsonEncode(toJson())}\n';

  /// Decode one JSON line. Surrounding whitespace is ignored.
  static KdeConnectPacket decode(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      throw const PacketFormatException('empty packet');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      throw PacketFormatException('invalid JSON: ${error.message}');
    }
    if (decoded is! Map) {
      throw const PacketFormatException('packet must be a JSON object');
    }
    return KdeConnectPacket.fromJson(_stringKeyedMap(decoded, 'packet'));
  }

  /// Decode all complete newline-terminated packets in [chunk].
  ///
  /// A trailing partial packet is ignored; callers must buffer it themselves
  /// when reading from a socket.
  static Iterable<KdeConnectPacket> decodeStream(String chunk) sync* {
    final buffer = StringBuffer();
    for (var index = 0; index < chunk.length; index++) {
      final character = chunk[index];
      if (character == '\n') {
        if (buffer.isNotEmpty) {
          yield decode(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(character);
      }
    }
  }

  static Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> map, String name) {
    final result = <String, Object?>{};
    map.forEach((key, value) {
      if (key is! String) {
        throw PacketFormatException('$name has a non-string key');
      }
      result[key] = value;
    });
    return result;
  }
}
