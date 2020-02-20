import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'rcon_client.dart';
import 'rcon_decoder.dart';

class RconType {
  /// RCON Packet Type 0: Server response
  static const int SERVERDATA_RESPONSE_VALUE = 0;

  /// RCON Packet Type 2: Server auth response
  static const int SERVERDATA_AUTH_RESPONSE = 2;

  /// RCON Packet Type 2: Client execute command
  static const int SERVERDATA_EXECCOMMAND = 2;

  /// RCON Packet Type 3: Client send authentication data
  static const int SERVERDATA_AUTH = 3;
}

/// Client for the rcon protocol
class RconClientImpl implements RconClient {
  /// Socket used to write and read TCP packets.
  Socket _socket;

  /// Disconnect from the a RCON server.
  ///
  /// Usage:
  ///
  /// ```dart
  /// RconClient client = RconClient.connect(print, 'localhost', '25575', 'password');
  /// client.exit();
  /// ```
  @override
  void exit() => _socket.destroy();

  /// Send commands
  @override
  void send(String cmd) => _send(RconType.SERVERDATA_EXECCOMMAND, cmd);

  /// Authenticate to the server
  void _authenticate(String password) =>
      _send(RconType.SERVERDATA_AUTH, password);

  /// Build and send a packet to the rcon server
  ///
  /// | Field        | Type                                | Value |
  /// |--------------|-------------------------------------|-------|
  /// | Size         | 32-bit little-endian Signed Integer |       |
  /// | ID           | 32-bit little-endian Signed Integer |       |
  /// | Type         | 32-bit little-endian Signed Integer |       |
  /// | Body         | Null-terminated ASCII String        |       |
  /// | Empty String | Null-terminated ASCII String        | 0x00  |
  void _send(int type, String payload) {
    final Uint8List outSize = Uint8List(4);
    final Uint8List outId = Uint8List(4); // Empty: 00 00 00 00
    final Uint8List outType = Uint8List(4);

    // Write type in the Type field
    final ByteData typeData = ByteData.view(outType.buffer);
    typeData.setInt32(0, type, Endian.little);

    // Build the body
    final List<int> outBody = utf8.encode(payload);

    // Build ID + Type + Body + Empty String
    final Uint8List outPacketBody =
        Uint8List.fromList(outId + outType + outBody + Uint8List(2));

    // Calculate the Size field
    final ByteData sizeData = ByteData.view(outSize.buffer);
    sizeData.setInt32(0, outPacketBody.length, Endian.little);

    // Build the packet
    final Uint8List packet = Uint8List.fromList(outSize + outPacketBody);

    // View packet
    // print(packet);
    // print(packet.map((int i) => i.toRadixString(16)).toList());
    // print(utf8.decode(packet));

    // Send the packet
    _socket.add(packet);
  }

  /// Connect to the a RCON server.
  ///
  /// Usage:
  ///
  /// ```dart
  /// final RconClient client = RconClient();
  /// final Stream<String> response = client.connect(
  ///   'localhost',
  ///   25575,
  ///   'password',
  /// );
  /// ```
  @override
  Stream<String> connect(String host, int port, String password) async* {
    print("Trying to connect...");

    _socket = await Socket.connect(host, port);

    print("Connected.");

    final Stream<String> stream = _socket.transform(RconDecoder());

    print("Trying to authenticate");

    _authenticate(password);

    yield* stream;
  }
}
