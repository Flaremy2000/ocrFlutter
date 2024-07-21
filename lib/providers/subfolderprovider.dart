import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubFolderProvider with ChangeNotifier {
  final String baseUrl = 'https://ocr.flaremy.net/api';
  List<dynamic> subFolders = [];
  int totalItems = 0;
  int perPage = 5;
  int currentPage = 1;
  String? token;
  bool expiredToken = false;

  void setToken(String? newToken){
    token = newToken;
    fetchSubFolders();
  }

  Future<void> fetchSubFolders({int? page = 1, int? perPage = 5, int? folderId}) async {
    var queryParameters = {
      'per_page': perPage.toString(),
      'page': page.toString(),
      'folder_id': folderId?.toString(),
    };
    final uri = Uri.parse('$baseUrl/subfolder').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      expiredToken = false;
      var jsonResponse = json.decode(response.body);
      subFolders = jsonResponse['items'];
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

  Future<void> setPage(int page, int folderId) async {
    await fetchSubFolders(page: page, perPage: perPage, folderId: folderId);
  }

  Future<void> setPerPage(int perPage, int folderId) async {
    await fetchSubFolders(page: 1, perPage: perPage, folderId: folderId);
  }

  Future<void> addSubFolder(String subFolderName, int folderId) async {
    final uri = Uri.parse('$baseUrl/subfolder');
    final response = await http.post(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, body: json.encode({
      'subfolder_name': subFolderName,
      'id_folder': folderId
    }));

    if (response.statusCode == 201) {
      expiredToken = false;
      await fetchSubFolders(folderId: folderId);
    } else if(response.statusCode == 401) {
      expiredToken = true;
      token = null;
      notifyListeners();
    }
  }

  Future<void> updateSubFolder(int subFolderId, String subFolderName, int folderId) async {
    final uri = Uri.parse('$baseUrl/subfolder/$subFolderId');
    final response = await http.put(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, body: json.encode({
      'subfolder_name': subFolderName,
      'id_folder': folderId
    }));

    if (response.statusCode == 200) {
      expiredToken = false;
      await fetchSubFolders(folderId: folderId);
      notifyListeners();
    } else if(response.statusCode == 401) {
      expiredToken = true;
      notifyListeners();
    }
  }

  Future<void> deleteSubFolder(int subFolderId, int folderId) async {
    final uri = Uri.parse('$baseUrl/subfolder/$subFolderId');
    final response = await http.delete(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      expiredToken = false;
      subFolders.removeWhere((subFolder) => subFolder['id'] == subFolderId);
      fetchSubFolders(folderId: folderId);
      notifyListeners();
    } else if(response.statusCode == 401) {
      expiredToken = true;
      token = null;
      notifyListeners();
    }
  }
  
  void handleTokenExpiration() {
    expiredToken = false;
    token = null;
    notifyListeners();
  }
}
