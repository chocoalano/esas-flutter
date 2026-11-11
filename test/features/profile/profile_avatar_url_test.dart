import 'dart:io';

import 'package:esas/core/config/asset_url.dart';
import 'package:esas/features/profile/presentation/views/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PROF-09. The identity card built the avatar URL by hand: an absolute URL
/// from another host, or a stored path with a leading slash, came out broken
/// (`<cdn>/https://…`, `<cdn>//avatars/…`). `assetUrl()` already handles both.
void main() {
  String urlOf(String stored) =>
      (profileAvatarImage(stored: stored)! as NetworkImage).url;

  test('an absolute URL is used as it is', () {
    expect(
      urlOf('https://storage.example.com/avatars/budi.png'),
      'https://storage.example.com/avatars/budi.png',
    );
  });

  test('a stored path resolves the way every other asset does', () {
    expect(urlOf('/avatars/budi.png'), assetUrl('avatars/budi.png'));
    expect(urlOf('avatars/budi.png'), assetUrl('avatars/budi.png'));
    expect(urlOf('/avatars/budi.png'), isNot(contains('//avatars')));
  });

  test('nothing stored is no picture; a fresh pick wins', () {
    expect(profileAvatarImage(stored: ''), isNull);
    expect(
      profileAvatarImage(picked: File('a.jpg'), stored: 'avatars/budi.png'),
      isA<FileImage>(),
    );
  });
}
