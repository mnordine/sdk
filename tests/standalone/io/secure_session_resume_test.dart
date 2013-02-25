// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// This test tests TLS session resume, by making multiple client connections
// on the same port to the same server, with a delay of 200 ms between them.
// The unmodified secure_server_test creates all sessions simultaneously,
// which means that no handshake completes and caches its keys in the session
// cache in time for other connections to use it.
//
// Session resume is currently disabled - see issue
// https://code.google.com/p/dart/issues/detail?id=7230
//
// VMOptions=
// VMOptions=--short_socket_read
// VMOptions=--short_socket_write
// VMOptions=--short_socket_read --short_socket_write

import "dart:async";
import "dart:io";
import "dart:isolate";

const SERVER_ADDRESS = "127.0.0.1";
const HOST_NAME = "localhost";
const CERTIFICATE = "localhost_cert";
Future<SecureServerSocket> startServer() {
  return SecureServerSocket.bind(SERVER_ADDRESS,
                                 0,
                                 5,
                                 CERTIFICATE).then((server) {
    server.listen((SecureSocket client) {
      client.reduce(<int>[], (message, data) => message..addAll(data))
          .then((message) {
            String received = new String.fromCharCodes(message);
            Expect.isTrue(received.contains("Hello from client "));
            String name = received.substring(received.indexOf("client ") + 7);
            client.add("Welcome, client $name".codeUnits);
            client.close();
          });
    });
    return server;
  });
}

Future testClient(server, name) {
  return SecureSocket.connect(HOST_NAME, server.port).then((socket) {
    socket.add("Hello from client $name".codeUnits);
    socket.close();
    return socket.reduce(<int>[], (message, data) => message..addAll(data))
        .then((message) {
          Expect.listEquals("Welcome, client $name".codeUnits, message);
          return server;
        });
  });
}

void main() {
  Path scriptDir = new Path(new Options().script).directoryPath;
  Path certificateDatabase = scriptDir.append('pkcert');
  SecureSocket.initialize(database: certificateDatabase.toNativePath(),
                          password: 'dartdart');

  Duration delay = const Duration(milliseconds: 0);
  Duration delay_between_connections = const Duration(milliseconds: 300);

  startServer()
      .then((server) => Future.wait(
          ['able', 'baker', 'charlie', 'dozen', 'elapse']
          .map((name) {
            delay += delay_between_connections;
            return new Future.delayed(delay, () => server)
            .then((server) => testClient(server, name));
          })))
      .then((servers) => servers.first.close());
}
