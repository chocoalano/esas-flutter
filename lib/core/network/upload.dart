import 'dart:io';
import 'dart:typed_data';

/// One file on its way to the server, however the device happened to hand it
/// over.
///
/// A picker does not always give back a path. A document chosen from Drive, or
/// from any provider that streams rather than stores, arrives as bytes with
/// `path == null` — and the permit form used to build its request from the path
/// alone, so the screen showed an attachment, the request went without one, and
/// the person who was told to bring a doctor's note found out days later that
/// they had not.
///
/// So the request layer takes this instead of a [File]: whatever the picker
/// gave, named, sized, and answerable about whether it can actually be sent.
class Upload {
  const Upload._({required this.filename, this.file, this.bytes});

  /// A file the platform stored somewhere this process can read.
  factory Upload.file(File file, {String? filename}) =>
      Upload._(filename: filename ?? file.uri.pathSegments.last, file: file);

  /// A file the picker handed over as bytes, with no path of its own.
  factory Upload.bytes(Uint8List bytes, {required String filename}) =>
      Upload._(filename: filename, bytes: bytes);

  /// The name the server files it under.
  final String filename;

  final File? file;
  final Uint8List? bytes;

  /// What `MultipartFile` is built from. It accepts either shape.
  Object get payload => (file ?? bytes)!;

  /// The size in bytes, or null when it cannot be known without reading the
  /// file — which is the case for a path that has since been deleted.
  int? get sizeInBytes {
    final data = bytes;

    if (data != null) {
      return data.lengthInBytes;
    }

    final source = file;

    if (source == null || !source.existsSync()) {
      return null;
    }

    return source.lengthSync();
  }
}
