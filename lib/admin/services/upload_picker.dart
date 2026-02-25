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
