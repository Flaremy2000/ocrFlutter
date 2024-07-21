import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class FileProvider with ChangeNotifier {
  final String baseUrl = 'https://ocr.flaremy.net/api';
  List<dynamic> file = [];
  int totalItems = 0;
  int perPage = 5;
  int currentPage = 1;
  String? token;
  bool expiredToken = false;

  void setToken(String? newToken){
    token = newToken;
    fetchDocuments();
  }

  // Obtener Documents
  Future<void> fetchDocuments({
    int? perPage = 5,
    int? page = 1,
    int? subfolderId,
    String? typeFile,
    bool? dateAsc = false,
    bool? dateDesc = false,
    bool? nameAsc = false,
    bool? nameDesc = false,
    String? q
  }) async {
    var queryParameters = {
      'per_page': perPage?.toString(),
      'page': page?.toString(),
      'subfolder_id': subfolderId?.toString(),
      'type_file': typeFile,
      'date_asc': dateAsc?.toString(),
      'date_desc': dateDesc?.toString(),
      'name_asc': nameAsc?.toString(),
      'name_desc': nameDesc?.toString(),
      'q': q,
    };

    queryParameters.removeWhere((key, value) => value == null);

    final uri = Uri.parse('$baseUrl/documents').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      expiredToken = false;
      var jsonResponse = json.decode(response.body);
      file = jsonResponse['items'];
      totalItems = jsonResponse['totalCounts'];
      this.perPage = perPage ?? this.perPage;
      currentPage = page ?? currentPage;
      notifyListeners();
    } else if(response.statusCode == 401) {
        expiredToken = true;
        token = null;
        notifyListeners();
    }
  }
  
Future<void> setPage(int page, int subfolderId) async {
  await fetchDocuments(page: page, perPage: perPage, subfolderId: subfolderId);
}

Future<void> setPerPage(int perPage, int subfolderId) async {
  this.perPage = perPage;
  await fetchDocuments(page: 1, perPage: perPage, subfolderId: subfolderId);
}


  // Agregar Document
  Future<void> addDocument(dynamic file, String userId, int subFolderId) async {
    final uri = Uri.parse('$baseUrl/documents');
    var request = http.MultipartRequest('POST', uri)
      ..fields['id_user'] = userId.toString()
      ..fields['id_subfolder'] = subFolderId.toString();
    
    if(kIsWeb){
        request.files.add(http.MultipartFile.fromBytes('document_content', file['bytes'] as Uint8List, filename: file['name']));
    }else{
      request.files.add(await http.MultipartFile.fromPath('document_content', file as String));
    }

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    final response = await request.send();

    if (response.statusCode == 201) {
      notifyListeners();
    } else if(response.statusCode == 401) {
      expiredToken = false;
      token = null;
    }
    notifyListeners();
  }

  // Actualizar Document
  Future<void> updateDocument(int documentId, dynamic file, int userId, int subFolderId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId');
    var request = http.MultipartRequest('POST', uri)
      ..fields['id_user'] = userId.toString()
      ..fields['id_subfolder'] = subFolderId.toString();
      
      if(kIsWeb){
        request.files.add(http.MultipartFile.fromBytes('document_content', file['bytes'] as Uint8List, filename: file['name']));
      }else{
        request.files.add(await http.MultipartFile.fromPath('document_content', file as String));
      }

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    final response = await request.send();

    if (response.statusCode == 200) {
      notifyListeners();
    } else if(response.statusCode == 401){
      expiredToken = false;
      token = null;
    }
    notifyListeners();
  }

  // Eliminar Document
  Future<void> deleteDocument(int documentId) async {
    final uri = Uri.parse('$baseUrl/documents/$documentId');
    final response = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      notifyListeners();
    } else {
      expiredToken = false;
      token = null;
    }

    notifyListeners();
  }
  
  void handleTokenExpiration() {
    expiredToken = false;
    token = null;
    notifyListeners();
  }
}
