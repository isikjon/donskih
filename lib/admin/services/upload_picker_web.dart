import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'upload_picker.dart';

Future<UploadPickResult?> pickVideoFileImpl() async {
  return _pickFileImpl('.mp4,.mov,.m4v,.mkv,.webm,.m3u8');
}

Future<UploadPickResult?> pickPdfFileImpl() async {
  return _pickFileImpl('.pdf,application/pdf');
}

Future<UploadPickResult?> _pickFileImpl(String accept) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;

  input.click();
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final reader = html.FileReader();
  final completer = Completer<UploadPickResult?>();

  reader.onError.listen((_) {
    completer.completeError('Не удалось прочитать файл');
  });
  reader.onLoadEnd.listen((_) {
    final bytes = _extractBytes(reader.result);
    if (bytes == null) {
      completer.completeError('Неподдерживаемый формат файла');
      return;
    }
    completer.complete(
      UploadPickResult(
        name: file.name,
        bytes: bytes,
        size: file.size,
      ),
    );
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}

Uint8List? _extractBytes(Object? result) {
  if (result == null) return null;
  if (result is Uint8List) return result;
  if (result is ByteBuffer) return Uint8List.view(result);
  if (result is ByteData) {
    return result.buffer
        .asUint8List(result.offsetInBytes, result.lengthInBytes);
  }
  if (result is List<int>) return Uint8List.fromList(result);
  if (result is String && result.startsWith('data:')) {
    final comma = result.indexOf(',');
    if (comma <= 0 || comma >= result.length - 1) return null;
    try {
      return base64Decode(result.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
  return null;
}
