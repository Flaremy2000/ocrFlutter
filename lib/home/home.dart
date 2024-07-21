import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ocr/Models/document.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:ocr/providers/fileprovider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:path/path.dart' as path;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? userType;
  List<Document> recentDocuments = [];
  List<Document> searchSuggestions = [];
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();
  AuthProvider? authProvider;
  FileProvider? fileProvider;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
      fileProvider = Provider.of<FileProvider>(context, listen: false);
      initializeUser().then((_) {
        fetchRecentDocuments();
    });
  });
  }

  Future<void> initializeUser() async {
    await authProvider!.getCurrentUser();
    final user = authProvider!.currentUser;

    if (authProvider!.expiredToken || user == null) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión expirada, por favor inicie sesión nuevamente.')),
        );
      }
      Navigator.of(context).pushReplacementNamed('/');
      authProvider!.handleTokenExpiration();
      return;
    }

    setState(() {
      userType = user['user_type'];
    });
  }

  Future<void> fetchRecentDocuments({String? query}) async {
    fileProvider?.setToken(authProvider?.token);
    if (authProvider!.expiredToken || authProvider!.currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/');
      authProvider!.handleTokenExpiration();
      return;
    }

    setState(() {
      isLoading = true;
    });

    await fileProvider?.fetchDocuments(perPage: 8, page: 1, dateDesc: true, q: query);

    if (fileProvider!.expiredToken) {
      Navigator.of(context).pushReplacementNamed('/');
      fileProvider!.handleTokenExpiration();
      return;
    }

    setState(() {
      recentDocuments = fileProvider!.file.map((item) => Document(
        id: item['id'],
        documentName: item['document_name'],
        documentType: item['document_type'],
        documentContent: item['document_content'],
      )).toList();
      isLoading = false;
    });
  }

  Future<void> fetchSearchSuggestions(String query) async {
    fileProvider!.setToken(authProvider?.token);
    await fileProvider!.fetchDocuments(perPage: 8, page: 1, q: query);
    setState(() {
      searchSuggestions = fileProvider!.file.map((item) => Document(
        id: item['id'],
        documentName: item['document_name'],
        documentType: item['document_type'],
        documentContent: item['document_content'],
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              style: const TextStyle(color:Color(0xC3000022)),
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar documentos...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xC3000022)),
                  onPressed: () => fetchRecentDocuments(query: searchController.text),
                ),
              ),
              onChanged: (value) {
                fetchSearchSuggestions(value);
              },
              onSubmitted: (value) {
                fetchRecentDocuments(query: value);
              },
            ),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        'Recientes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xC3000022)),
                      ),
                      const SizedBox(height: 8),
                      isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xC3000022),))
                      : Expanded(
                        child: ListView.builder(
                          itemCount: searchController.text.isEmpty
                            ? recentDocuments.length
                            : searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final document = searchController.text.isEmpty
                              ? recentDocuments[index]
                              : searchSuggestions[index];
                            return Card(
                              color: const Color(0xFFFFF3F8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: _getDocumentIcon(document.documentType),
                                title: Text('${document.documentName}.${document.documentType}', style: const TextStyle(color: Color(0xC3000022)),),
                                trailing: PopupMenuButton<String>(
                                  color: const Color(0xFFFFF3F8),
                                  onSelected: (value) => _handleItemMenuAction(value, document),
                                  itemBuilder: (BuildContext context) {
                                    List<String> choices = ['Editar', 'Borrar', 'Descargar'];
                                    if (userType == 'Manager') {
                                      choices.remove('Editar');
                                      choices.remove('Borrar');
                                    }
                                    return choices.map((String choice) {
                                      return PopupMenuItem<String>(
                                        value: choice,
                                        child: Text(choice, style: const TextStyle(color: Color(0xC3000022)),),
                                      );
                                    }).toList();
                                  },
                                  icon: const Icon(Icons.more_vert, color: Color(0xC3000022),),
                                ),
                                onTap: () => _previewDocument(document),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _handleItemMenuAction(String choice, Document document) {
    if (choice == 'Editar' && userType != 'Manager') {
      _showEditDocumentDialog(document);
    } else if (choice == 'Borrar' && userType != 'Manager') {
      _showDeleteConfirmationDialog(document.id);
    } else if (choice == 'Descargar') {
      _downloadDocument(document);
    }
  }

  void _previewDocument(Document document) {
    if (kDebugMode) {
      print('Previewing document: ${document.documentName}.${document.documentType}');
    }
    if (document.documentType == 'pdf') {
      _showPdfPreview(document.documentContent);
    } else if (document.documentType == 'png' || document.documentType == 'jpeg' || document.documentType == 'jpg') {
      _showImagePreview(document.documentContent);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vista previa no disponible'),
          content: const Text('Vista previa no compatible para este tipo de documento'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _getDocumentIcon(String documentType) {
    switch (documentType) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Color(0xC3000022));
      case 'png':
      case 'jpeg':
      case 'jpg':
        return const Icon(Icons.image, color: Color(0xC3000022));
      case 'word':
        return const Icon(Icons.description, color: Color(0xC3000022));
      case 'excel':
        return const Icon(Icons.table_chart, color: Color(0xC3000022));
      default:
        return const Icon(Icons.insert_drive_file, color: Color(0xC3000022));
    }
  }

  void _showPdfPreview(String documentContentBase64) {
    try {
      Uint8List bytes = base64Decode(documentContentBase64);
      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, "_blank");
        html.Url.revokeObjectUrl(url);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Vista previa PDF', style: TextStyle(color: Color(0xC3000022)),)),
              body: SfPdfViewer.memory(bytes),
            ),
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text('Error', style: TextStyle(color: Color(0xC3000022)),),
          content: const Text('No se pudo mostrar la vista previa del PDF.', style: TextStyle(color: Color(0xC3000022)),),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar', style: TextStyle(color: Color(0xC3000022)),),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showImagePreview(String documentContentBase64) {
    try {
      Uint8List bytes = base64Decode(documentContentBase64.split(',').last);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Image.memory(bytes),
          );
        },
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text('Error', style: TextStyle(color: Color(0xC3000022)),),
          content: const Text('No se pudo mostrar la vista previa de la imagen.', style: TextStyle(color: Color(0xC3000022)),),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar', style: TextStyle(color: Color(0xC3000022)),),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showEditDocumentDialog(Document document) async {
    fileProvider?.setToken(authProvider?.token);
    bool isLoadFile = false;
    dynamic selectedFile;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text("Editar Documento", style: TextStyle(color: Color(0xC3000022)),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  selectedFile = await _selectFile();
                  setState(() {});
                },
                child: const Text("Seleccionar Archivo", style: TextStyle(color: Color(0xC3000022)),),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022)),),
            ),
            TextButton(
              onPressed: () async {
                if (selectedFile != null) {
                  setState(() {
                    isLoadFile = true;
                  });

                  try {
                    if (kIsWeb) {
                      await fileProvider?.updateDocument(
                        document.id,
                        selectedFile,
                        1,
                        1,
                      );
                    } else {
                      await fileProvider?.updateDocument(
                        document.id,
                        (selectedFile as io.File).path,
                        1,
                        1,
                      );
                    }

                    if (mounted) {
                      setState(() {
                        selectedFile = null;
                        isLoadFile = false;
                      });
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Documento actualizado correctamente', style: TextStyle(color: Color(0xC3000022)),), backgroundColor: Color(0xFFFFF3F8),),
                    );
                    Navigator.of(context).pop();
                    await fetchRecentDocuments();
                  } catch (e) {
                    if (kDebugMode) {
                      print('Error updating document: $e');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al actualizar el documento', style: TextStyle(color: Color(0xC3000022)),), backgroundColor: Color(0xFFFFF3F8),),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor seleccione un archivo', style: TextStyle(color: Color(0xC3000022)),), backgroundColor: Color(0xC3000022),),
                  );
                }
              },
              child: isLoadFile ? const CircularProgressIndicator(color: Color(0xC3000022),) : const Text("Actualizar", style: TextStyle(color: Color(0xC3000022)),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(int documentId) async {
    fileProvider?.setToken(authProvider?.token);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text("Confirmar Eliminación", style: TextStyle(color: Color(0xC3000022)),),
          content: const Text("¿Está seguro de que quiere borrar este documento?", style: TextStyle(color: Color(0xC3000022)),),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022)),),
            ),
            TextButton(
              onPressed: () async {
                await fileProvider?.deleteDocument(documentId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Documento eliminado correctamente', style: TextStyle(color: Color(0xC3000022)),)),
                );
                await fetchRecentDocuments();
              },
              child: const Text("Borrar", style: TextStyle(color: Color(0xC3000022)),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadDocument(Document document) async {
    String documentName = document.documentName;
    String documentType = document.documentType;
    String documentContentBase64 = document.documentContent;
    Uint8List bytes = base64Decode(documentContentBase64.split(',').last);

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "$documentName.$documentType")
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Archivo descargado correctamente', style: TextStyle(color: Color(0xC3000022)),)),
      );
    } else {
      if (await Permission.storage.request().isGranted) {
        io.Directory? directory;
        if (io.Platform.isAndroid) {
          directory = io.Directory('/storage/emulated/0/Download');
        } else if (io.Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          String filePath = path.join(directory.path, '$documentName.$documentType');
          final file = await io.File(filePath).writeAsBytes(bytes);
          OpenFile.open(file.path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Archivo descargado correctamente', style: TextStyle(color: Color(0xC3000022)),)),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFFFFF3F8),
              title: const Text('Error', style: TextStyle(color: Color(0xC3000022)),),
              content: const Text('No se pudo acceder a la carpeta de Descargas.', style: TextStyle(color: Color(0xC3000022)),),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cerrar', style: TextStyle(color: Color(0xC3000022)),),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFFFF3F8),
            title: const Text('Permiso Denegado', style: TextStyle(color: Color(0xC3000022)),),
            content: const Text('No se puede guardar el archivo sin permisos de almacenamiento.', style: TextStyle(color: Color(0xC3000022)),),
            actions: <Widget>[
              TextButton(
                child: const Text('Cerrar', style: TextStyle(color: Color(0xC3000022)),),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  Future<dynamic> _selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      if (kIsWeb) {
        if (result.files.first.bytes != null) {
          return {
            'bytes': result.files.first.bytes,
            'name': result.files.first.name,
          };
        }
      } else {
        if (result.files.single.path != null) {
          return io.File(result.files.single.path!);
        }
      }
    }
    return null;
  }
}
