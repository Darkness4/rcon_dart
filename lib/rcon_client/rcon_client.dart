import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Client for the rcon protocol
///
/// [host] can either be a [String] or an [InternetAddress]. If [host] is a
/// [String], [connect] will perform a [InternetAddress.lookup] and try all
/// returned [InternetAddress]es, until connected. Unless a connection was
/// established, the error from the first failing connection is returned.
///
/// Usage:
///
/// ```dart
/// RconClient client = RconClient.connect(print, 'localhost', '25575', 'password');
///
/// // Send one command
/// client.send('help');
///
/// // Send each data from standard input
/// await stdin
///   .transform(utf8.decoder)
///   .transform(const LineSplitter())
///   .forEach(client.send);
/// ```
class RconClient {
  /// RCON Packet Type 0: Server response
  static const int SERVERDATA_RESPONSE_VALUE = 0;

  /// RCON Packet Type 2: Server auth response
  static const int SERVERDATA_AUTH_RESPONSE = 2;

  /// RCON Packet Type 2: Client execute command
  static const int SERVERDATA_EXECCOMMAND = 2;

  /// RCON Packet Type 3: Client send authentication data
  static const int SERVERDATA_AUTH = 3;

  /// Password used to connect to the RCON server
  final String _password;

  /// Socket used to write and read TCP packets.
  final Socket _socket;

  RconClient({String password, Socket socket})
      : _password = password,
        _socket = socket;

  /// Disconnect from the a RCON server.
  ///
  /// Usage:
  ///
  /// ```dart
  /// RconClient client = RconClient.connect(print, 'localhost', '25575', 'password');
  /// client.exit();
  /// ```
  void exit() => _socket.destroy();

  /// Send commands
  void send(String cmd) => _send(SERVERDATA_EXECCOMMAND, cmd);

  /// Authenticate to the server
  void _authenticate() => _send(SERVERDATA_AUTH, _password);

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
  /// RconClient client = RconClient.connect(print, 'localhost', '25575', 'password');
  /// ```
  static Future<RconClient> connect(void Function(String) onData,
      {dynamic host, int port, String password}) async {
    try {
      print("Trying to connect...");

      final RconClient client = RconClient(
        password: password,
        socket: await Socket.connect(host, port),
      );

      // Add a reader
      client._socket.listen(
        (Uint8List packet) => dataListener(packet, onData),
        cancelOnError: false,
        onDone: client.exit,
        onError: print,
      );

      client._authenticate();

      return client;
    } catch (e) {
      print("Unable to connect: $e");
    }
    return null;
  }

  /// Reponse to a data, usually a print.
  ///
  /// | Field        | Type                                | Value |
  /// |--------------|-------------------------------------|-------|
  /// | Size         | 32-bit little-endian Signed Integer |       |
  /// | ID           | 32-bit little-endian Signed Integer |       |
  /// | Type         | 32-bit little-endian Signed Integer |       |
  /// | Body         | Null-terminated ASCII String        |       |
  /// | Empty String | Null-terminated ASCII String        | 0x00  |
  static void dataListener(Uint8List data, void Function(String) onData) {
    final ByteData byteData = ByteData.view(data.buffer);
    // final int inLength = byteData.getInt32(0, Endian.little);
    final int inId = byteData.getInt32(4, Endian.little);
    final int inType = byteData.getInt32(8, Endian.little);
    final Uint8List inBody = data.sublist(12);

    if (inId == -1) {
      throw Exception('Bad login.');
    }
    if (inType == SERVERDATA_AUTH_RESPONSE) {
      print('Authentication successful. You can now write commands.');
    }

    onData(String.fromCharCodes(inBody));
  }
}
