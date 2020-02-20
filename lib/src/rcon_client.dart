import 'package:rcon_dart/src/rcon_client_impl.dart';

abstract class RconClient {
  void exit();

  void send(String cmd);

  factory RconClient() => RconClientImpl();

  Stream<String> connect(String host, int port, String password);
}
