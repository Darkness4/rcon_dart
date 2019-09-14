# Dart RCON

A RCON client based on Dart.

## Using

```dart
// Using print as the reader
RconClient client = RconClient.connect(print, 'localhost', '25575', 'password');

// Send one command
client.send('help');

// Send each data from standard input
await stdin
  .transform(utf8.decoder)
  .transform(const LineSplitter())
  .forEach(client.send);
```
