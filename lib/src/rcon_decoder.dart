import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:rcon_dart/src/rcon_client_impl.dart';

class RconDecoder extends Converter<Uint8List, String> {
  /// Transform packets into a String.
  ///
  /// | Field        | Type                                | Value |
  /// |--------------|-------------------------------------|-------|
  /// | Size         | 32-bit little-endian Signed Integer |       |
  /// | ID           | 32-bit little-endian Signed Integer |       |
  /// | Type         | 32-bit little-endian Signed Integer |       |
  /// | Body         | Null-terminated ASCII String        |       |
  /// | Empty String | Null-terminated ASCII String        | 0x00  |
  @override
  String convert(Uint8List data) {
    final ByteData byteData = ByteData.view(data.buffer);
    // final int inLength = byteData.getInt32(0, Endian.little);
    final int inId = byteData.getInt32(4, Endian.little);
    final int inType = byteData.getInt32(8, Endian.little);
    final Uint8List inBody = data.sublist(12);

    if (inType == RconType.SERVERDATA_AUTH_RESPONSE) {
      if (inId == -1) {
        throw const SocketException('Bad login.');
      } else if (inId == 0) {
        return 'Authentication successful. You can now write commands.';
      }
    }

    return String.fromCharCodes(inBody);
  }

  @override
  ChunkedConversionSink<Uint8List> startChunkedConversion(Sink<String> sink) {
    StringConversionSink stringSink;
    if (sink is StringConversionSink) {
      stringSink = sink;
    } else {
      stringSink = StringConversionSink.from(sink);
    }
    return _RconEncoderSink(stringSink);
  }

  // Override the base class's bind, to provide a better type.
  @override
  Stream<String> bind(Stream<Uint8List> stream) => super.bind(stream);
}

class _RconEncoderSink extends ChunkedConversionSink<Uint8List> {
  final RconDecoder _converter;
  final ChunkedConversionSink<String> _outSink;

  _RconEncoderSink(this._outSink) : _converter = RconDecoder();

  @override
  void add(Uint8List data) {
    _outSink.add(_converter.convert(data));
  }

  @override
  void close() {
    _outSink.close();
  }
}
