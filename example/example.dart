import 'dart:convert';
import 'dart:io';

import 'package:rcon_dart/rcon_dart.dart';

Future<void> main(List<String> arguments) async {
  final RconClient client = await RconClient.connect(
    print,
    host: 'localhost',
    port: 25575,
    password: 'password',
  );

  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(client.send);
}
