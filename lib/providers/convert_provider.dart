import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;


class ConversionProvider with ChangeNotifier {
  
  final String apiKey = '26cdfaeec56a2e663c3d527deee50c5182b5aaf6';
  final String baseUri = 'https://api.zamzar.com/v1/';
  // final String baseUri = 'https://sandbox.zamzar.com/v1/';
  bool isLoading = false;
  String message = '';
  
  void _updateStatus(bool loading, [String msg = '']) {
    isLoading = loading;
    message = msg;
    notifyListeners();
  }



  Future<void> convertFile(dynamic file, String targetFormat) async {
    try{
      _updateStatus(true, 'Iniciando conversión...');

      var uri = Uri.parse('${baseUri}jobs');
      var request = http.MultipartRequest('POST', uri)
        ..fields['target_format'] = targetFormat
        ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$apiKey:'))}';
        
      if(kIsWeb){
        request.files.add(http.MultipartFile.fromBytes('source_file', file['bytes'] as Uint8List, filename: file['name'], contentType: MediaType('application', 'pdf')));
      }else{
        request.files.add(await http.MultipartFile.fromPath('source_file', file as String));
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        var responseData = await response.stream.toBytes();
        var result = json.decode(utf8.decode(responseData));
        if (kDebugMode) {
          print('Iniciar conversion: $result');
        }
        _updateStatus(true, 'Conversión iniciada. Esperando resultados...');

        checkJobStatus(result['id'], targetFormat);
      } else {
        _updateStatus(true, 'Error al iniciar la conversión.');
        if (kDebugMode) {
          print('Error iniciando conversion: ${response.statusCode}');
        }
        Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
      }
    }catch(e){
      _updateStatus(true, 'Error al iniciar la conversión.');
      if (kDebugMode) {
        print(e);
      }
      Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
    }
  }

  Future<void> checkJobStatus(int jobId, String targetFormat) async {
    _updateStatus(true, 'Conversión iniciada. Esperando resultados...');
    var uri = Uri.parse('${baseUri}jobs/$jobId');
    var response = await http.get(uri, headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:'))}'
    });

    if (response.statusCode == 200) {
      var jobDetails = json.decode(response.body);
      if (kDebugMode) {
        print('Job Status: $jobDetails');
      }
      if (jobDetails['status'] == 'successful') {
        _updateStatus(true, 'Conversión finalizada. Esperando resultados...');
        downloadFile(jobDetails['target_files'][0]['id'], targetFormat);
      } else {
        Future.delayed(const Duration(seconds: 30), () => checkJobStatus(jobId, targetFormat));
      }
    } else {
        _updateStatus(true, 'Error obteniendo el estado de la conversion.');
      if (kDebugMode) {
        print('Error revisando el estado del trabajo: ${response.statusCode}');
      }
      Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
    }
  }

  Future<void> downloadFile(int fileId, String targetFormat) async {
    _updateStatus(true, 'Descargando archivo...');
    var uri = Uri.parse('${baseUri}files/$fileId/content');
    var response = await http.get(uri, headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:'))}',
      'Access-Control-Allow-Headers' : 'Access-Control-Allow-Origin, Accept'
    });

    if (response.statusCode == 200) {
      Uint8List fileBytes = response.bodyBytes;
      if (kIsWeb) {
        _saveFileOnWeb(fileBytes, 'fileconvert${formatDateTime(DateTime.now())}.$targetFormat');
      } else {
        _saveFileOnMobile(fileBytes, 'fileconvert${formatDateTime(DateTime.now())}.$targetFormat');
      }
      Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
    } else {
      _updateStatus(true, 'Fallo al descargar el archivo.');
      if (kDebugMode) {
        print('Failed to download file: ${response.statusCode}');
      }
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
        _updateStatus(true, 'No se pudo acceder a la carpeta descargas');
        if (kDebugMode) {
          print('Access to the directory is denied');
        }
        Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
      }
    } else {
      _updateStatus(true, 'No hay los permisos necesarios para guardar la conversion.');
      if (kDebugMode) {
        print('Storage permission is denied');
      }
      Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
    }
    
    Future.delayed(const Duration(seconds: 3), () => _updateStatus(false, ''));
  }

  String formatDateTime(DateTime dateTime) {
  return '${dateTime.year}'
         '${dateTime.month.toString().padLeft(2, '0')}'
         '${dateTime.day.toString().padLeft(2, '0')}_'
         '${dateTime.hour.toString().padLeft(2, '0')}'
         '${dateTime.minute.toString().padLeft(2, '0')}'
         '${dateTime.second.toString().padLeft(2, '0')}';
}
}