import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/link_preview_service.dart';
import 'package:glimpse/core/utils/network/url_security_validator.dart';

void main() {
  group('UrlSecurityValidator', () {
    late UrlSecurityValidator validator;

    setUp(() {
      validator = UrlSecurityValidator(
        resolver: (host) async {
          switch (host) {
            case 'public.example':
              return [InternetAddress('93.184.216.34')];
            case 'private.example':
              return [InternetAddress('10.0.0.4')];
            default:
              return [InternetAddress('192.168.1.10')];
          }
        },
      );
    });

    test('allows public http and https URLs', () async {
      expect(await validator.isSafePublicUrl('https://public.example/a'), true);
      expect(await validator.isSafePublicUrl('http://public.example/a'), true);
    });

    test('rejects blocked schemes and local hosts', () async {
      expect(await validator.isSafePublicUrl('file:///tmp/a'), false);
      expect(await validator.isSafePublicUrl('ftp://public.example/a'), false);
      expect(await validator.isSafePublicUrl('data://text/plain,a'), false);
      expect(await validator.isSafePublicUrl('javascript:alert(1)'), false);
      expect(await validator.isSafePublicUrl('http://localhost:8080'), false);
    });

    test('rejects private and link-local IPv4 literals', () async {
      expect(await validator.isSafePublicUrl('http://127.0.0.1'), false);
      expect(await validator.isSafePublicUrl('http://10.1.2.3'), false);
      expect(await validator.isSafePublicUrl('http://192.168.1.20'), false);
      expect(await validator.isSafePublicUrl('http://172.16.0.1'), false);
      expect(await validator.isSafePublicUrl('http://172.31.255.255'), false);
      expect(await validator.isSafePublicUrl('http://169.254.1.2'), false);
    });

    test('rejects public hostnames that resolve to private addresses', () async {
      expect(await validator.isSafePublicUrl('https://private.example'), false);
      expect(await validator.resolvesToPrivateIp('private.example'), true);
    });

    test('rejects redirect chains that end at private URLs', () async {
      expect(
        await validator.validateRedirectChain([
          'https://public.example/start',
          'http://127.0.0.1/admin',
        ]),
        false,
      );
    });

    test('sync URL validation blocks obvious unsafe URLs before extraction', () {
      expect(LinkPreviewService.isValidUrl('https://public.example'), true);
      expect(LinkPreviewService.isValidUrl('http://127.0.0.1'), false);
      expect(LinkPreviewService.isValidUrl('file:///tmp/a'), false);
    });
  });
}
