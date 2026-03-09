import 'upload_picker.dart';

Future<UploadPickResult?> pickVideoFileImpl() async {
  throw UnsupportedError('Video picker is available only in web admin');
}

Future<UploadPickResult?> pickPdfFileImpl() async {
  throw UnsupportedError('PDF picker is available only in web admin');
}

Future<Map<String, dynamic>?> uploadWithProgressWeb({
  required String url,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
}) async {
  throw UnsupportedError('Web upload is available only in web admin');
}
