import 'upload_picker.dart';

Future<UploadPickResult?> pickVideoFileImpl() async {
  throw UnsupportedError('Video picker is available only in web admin');
}

Future<UploadPickResult?> pickPdfFileImpl() async {
  throw UnsupportedError('PDF picker is available only in web admin');
}
