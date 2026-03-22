import 'upload_picker.dart';

Future<UploadPickResult?> pickVideoFileImpl() async {
  throw UnsupportedError('Video picker is available only in web admin');
}

Future<UploadPickResult?> pickPdfFileImpl() async {
  throw UnsupportedError('PDF picker is available only in web admin');
}

Future<UploadPickResult?> pickImageFileImpl() async {
  throw UnsupportedError('Image picker is available only in web admin');
}

Future<Map<String, dynamic>?> uploadWithProgressWeb({
  required String url,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
  dynamic nativeFile,
}) async {
  throw UnsupportedError('Web upload is available only in web admin');
}

Future<dynamic> pickVideoFileNative() async {
  throw UnsupportedError('Native video picker is available only in web admin');
}

Future<Map<String, dynamic>?> uploadNativeFileWithProgress({
  required String url,
  required String fieldName,
  required dynamic nativeFile,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
}) async {
  throw UnsupportedError('Native file upload is available only in web admin');
}
