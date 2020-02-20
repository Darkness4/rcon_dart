import 'dart:convert';
import 'dart:io';

import 'package:rcon_dart/rcon_dart.dart';

Future<void> main(List<String> arguments) async {
  final RconClient client = RconClient();
  final Stream<String> response = client.connect(
    '10.163.0.50',
    25575,
    'minitel',
  );

  response.listen(print);

  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(client.send);
}
