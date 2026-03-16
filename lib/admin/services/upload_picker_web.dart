import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'upload_picker.dart';

/// Upload file via XMLHttpRequest with real progress tracking (web only).
/// Accepts either [bytes] (legacy) or [nativeFile] (preferred for large files —
/// avoids loading the entire file into Dart memory).
Future<Map<String, dynamic>?> uploadWithProgressWeb({
  required String url,
  required String fieldName,
  required String filename,
  required List<int> bytes,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
  html.File? nativeFile,
}) async {
  final completer = Completer<Map<String, dynamic>?>();
  final formData = html.FormData();

  if (nativeFile != null) {
    formData.appendBlob(fieldName, nativeFile, filename);
  } else {
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    formData.appendBlob(fieldName, blob, filename);
  }

  final totalSize = nativeFile?.size ?? bytes.length;

  final xhr = html.HttpRequest();
  xhr.open('POST', url);
  headers.forEach((k, v) => xhr.setRequestHeader(k, v));

  xhr.upload.onProgress.listen((e) {
    if (e.lengthComputable && onProgress != null) {
      onProgress(e.loaded ?? 0, e.total ?? totalSize);
    }
  });

  xhr.onLoad.listen((_) {
    if (xhr.status == 200) {
      try {
        completer.complete(
            jsonDecode(xhr.responseText ?? '{}') as Map<String, dynamic>);
      } catch (e) {
        completer.completeError('Ошибка парсинга ответа: $e');
      }
    } else {
      completer.completeError('HTTP ${xhr.status}: ${xhr.responseText}');
    }
  });

  xhr.onError.listen((_) {
    completer.completeError('Ошибка сети при загрузке');
  });

  xhr.onAbort.listen((_) {
    completer.completeError('Загрузка отменена');
  });

  xhr.send(formData);
  return completer.future;
}

/// Upload a large file by passing the native html.File directly to XHR,
/// without reading it into Dart memory. Returns the parsed JSON response.
Future<Map<String, dynamic>?> uploadNativeFileWithProgress({
  required String url,
  required String fieldName,
  required html.File nativeFile,
  required Map<String, String> headers,
  void Function(int sent, int total)? onProgress,
}) {
  return uploadWithProgressWeb(
    url: url,
    fieldName: fieldName,
    filename: nativeFile.name,
    bytes: const [],
    headers: headers,
    onProgress: onProgress,
    nativeFile: nativeFile,
  );
}

Future<UploadPickResult?> pickVideoFileImpl() async {
  return _pickFileImpl('.mp4,.mov,.m4v,.mkv,.webm,.m3u8');
}

Future<UploadPickResult?> pickPdfFileImpl() async {
  return _pickFileImpl('.pdf,application/pdf');
}

/// Pick a video file and return the native html.File handle (no memory read).
Future<html.File?> pickVideoFileNative() async {
  final input = html.FileUploadInputElement()
    ..accept = '.mp4,.mov,.m4v,.mkv,.webm,.m3u8'
    ..multiple = false;
  input.click();
  await input.onChange.first;
  return input.files?.isNotEmpty == true ? input.files!.first : null;
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
