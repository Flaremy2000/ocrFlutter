import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;


class OCRConversionProvider with ChangeNotifier {
  final String apiKey = 'B550B011-7503-4B9C-8087-A8E73D0C4B62';
  final String apiBaseURL = 'https://www.ocrwebservice.com/restservices/processDocument';
  final String username = "Evelyn27";
  bool isLoading = false;
  String message = '';
  
  void _updateStatus(bool loading, [String msg = '']) {
    isLoading = loading;
    message = msg;
    notifyListeners();
  }

Future<void> performOCR(dynamic imagePath, String extensionFormat) async {
  _updateStatus(true, 'Inicio conversion OCR a $extensionFormat');
  var uri = Uri.parse('$apiBaseURL?language=spanish&pagerange=allpages&outputformat=$extensionFormat');

    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$username:$apiKey'))}'
      ..headers['Content-Type'] = 'multipart/form-data';
    
  if(kIsWeb){
    request.files.add(http.MultipartFile.fromBytes('source_file', imagePath['bytes'] as Uint8List, filename: imagePath['name']));
  } else {
    request.files.add(await http.MultipartFile.fromPath('source_file', imagePath as String));
  }

  var response = await request.send();

  if (response.statusCode == 200) {
    var responseData = await response.stream.bytesToString();
    var result = jsonDecode(responseData);
    _updateStatus(true, 'OCR completado correctamente. Espere la descarga....');
    if (result['OutputFileUrl'] != null) {
      await _downloadFile(result['OutputFileUrl'], extensionFormat);
    }
    notifyListeners();
  } else {
    _updateStatus(true, 'Error en OCR: ${response.statusCode}');
    Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
  }

}

Future<void> _downloadFile(String fileUrl, String extensionFormat) async {
  _updateStatus(true, 'Descargando archivo....');
  var response = await http.get(Uri.parse(fileUrl));
  if (response.statusCode == 200) {
    String filename = 'downloaded_file.$extensionFormat';
    if (kIsWeb) {
      _saveFileOnWeb(response.bodyBytes, filename);
    } else {
      _saveFileOnMobile(response.bodyBytes, filename);
    }
  } else {
    _updateStatus(true, 'Hubo un error al descargar el archivo');
    Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
  }

}

  void _saveFileOnWeb(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
  }

  Future<void> _saveFileOnMobile(Uint8List bytes, String filename) async {
    if (await Permission.storage.request().isGranted) {
      io.Directory? directory;
      if (io.Platform.isAndroid) {
        directory = io.Directory('/storage/emulated/0/Download');
      } else if (io.Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        String filePath = path.join(directory.path, filename);
        final file = await io.File(filePath).writeAsBytes(bytes);
        OpenFile.open(file.path);
        _updateStatus(true, 'Archivo guardado en carpeta descargas');
      } else {
        if (kDebugMode) {
          print('Access to the directory is denied');
        }
      }
    } else {
      if (kDebugMode) {
        print('Storage permission is denied');
      }
    }
    Future.delayed(const Duration(seconds: 5), () => _updateStatus(false, ''));
  }

}
