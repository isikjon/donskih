import 'upload_picker_stub.dart'
    if (dart.library.html) 'upload_picker_web.dart';

class UploadPickResult {
  final String name;
  final List<int> bytes;
  final int size;

  const UploadPickResult({
    required this.name,
    required this.bytes,
    required this.size,
  });
}

Future<UploadPickResult?> pickVideoFile() => pickVideoFileImpl();
Future<UploadPickResult?> pickPdfFile() => pickPdfFileImpl();

/// Web-only upload with real XHR progress. On non-web throws.
Future<Map<String, dynamic>?> uploadFileWithProgress({
  required String url,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
}) =>
    uploadWithProgressWeb(
      url: url,
      fieldName: fieldName,
      filename: filename,
      bytes: bytes,
      headers: headers,
      onProgress: onProgress,
    );

/// Pick a video file returning the native handle (web-only, no memory read).
/// Returns null on non-web or if user cancels.
Future<Object?> pickVideoNative() => pickVideoFileNative();

/// Upload a large file using its native handle (web-only). Streams from disk.
Future<Map<String, dynamic>?> uploadNativeFile({
  required String url,
  required String fieldName,
  required Object nativeFile,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
}) =>
    uploadNativeFileWithProgress(
      url: url,
      fieldName: fieldName,
      nativeFile: nativeFile as dynamic,
      headers: headers,
      onProgress: onProgress,
    );
