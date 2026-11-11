import 'dart:io';

import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/dev_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dev_http_overrides', () {
    test('installDevHttpOverrides never installs overrides in non-development mode', () {
      expect(Env.isDevelopment, isFalse);
      installDevHttpOverrides();
      expect(HttpOverrides.current, isNull);
    });

    test('isDevelopmentHost correctly differentiates dev and prod hosts', () {
      expect(ServerConfig.isDevelopmentHost('127.0.0.1'), isTrue);
      expect(ServerConfig.isDevelopmentHost('192.168.1.10'), isTrue);
      expect(ServerConfig.isDevelopmentHost('company.test'), isTrue);
      expect(ServerConfig.isDevelopmentHost('localhost'), isTrue);
      expect(ServerConfig.isDevelopmentHost('api.esas.com'), isFalse);
      expect(ServerConfig.isDevelopmentHost('google.com'), isFalse);
      expect(ServerConfig.isDevelopmentHost('10.0.2.2'), isTrue); // Android emulator loopback
      expect(ServerConfig.isDevelopmentHost('172.16.0.5'), isTrue); // RFC 1918 private IP
      expect(ServerConfig.isDevelopmentHost('app.esas.co.id'), isFalse);
    });

    test('badCertificateCallback refuses public and commercial hosts', () {
      // Direct inspection of host policy
      expect(ServerConfig.isDevelopmentHost('absensas.com'), isFalse);
      expect(ServerConfig.isDevelopmentHost('auth.esas.id'), isFalse);
      expect(ServerConfig.isDevelopmentHost('104.21.55.2'), isFalse);
    });
  });
}
