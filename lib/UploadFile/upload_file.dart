import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:ocr/providers/auth_provider.dart';
import 'package:ocr/providers/folderprovider.dart';
import 'package:ocr/providers/subfolderprovider.dart';
import 'package:ocr/providers/fileprovider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;

class UploadFile extends StatefulWidget {
  const UploadFile({super.key});

  @override
  _UploadFileState createState() => _UploadFileState();
}

class _UploadFileState extends State<UploadFile> {
  int viewType = 0;
  bool showingSubFolders = false;
  bool showingDocuments = false;
  int? currentFolderId;
  int? currentSubFolderId;
  Timer? _timer;
  bool isLoading = false;
  dynamic selectedFile;
  String? userType;
  Map<String, String>? user;
  AuthProvider? authProvider;
  FolderProvider? folderProvider;
  SubFolderProvider? subFolderProvider;
  FileProvider? fileProvider;

  String? filterOption = 'name_asc';

  // Local variables for pagination
  int totalPages = 1;
  int currentPage = 1;
  int itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<AuthProvider>(context, listen: false);
    folderProvider = Provider.of<FolderProvider>(context, listen: false);
    subFolderProvider = Provider.of<SubFolderProvider>(context, listen: false);
    fileProvider = Provider.of<FileProvider>(context, listen: false);
    folderProvider?.setToken(authProvider!.token);
    subFolderProvider?.setToken(authProvider!.token);
    fileProvider?.setToken(authProvider!.token);
    
    initializeResources();

    if (!kIsWeb) {
      _requestPermissions();
    }
    if (kIsWeb) {
      _timer = Timer.periodic(const Duration(minutes: 5), (Timer t) => _fetchData(reset: true));
    }
  }
  
  void initializeResources() async {
    setState(() => isLoading = true);
    await _initializeUser();
    await _fetchData();
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    await authProvider?.getCurrentUser();
    user = authProvider?.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          userType = user?['user_type'];
        });
      }
      _fetchData();
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  Future<void> _fetchData({bool reset = false}) async {
    setState(() {
      isLoading = true;
    });

    if (reset) {
      currentPage = 1;
    } 

    await folderProvider?.fetchFolders(perPage: itemsPerPage, page: currentPage);
    totalPages = (folderProvider!.totalItems / itemsPerPage).ceil();

    setState(() {
      isLoading = false;
    });

    checkTokenExpiration(folderProvider);
  }

  Future<void> _fetchSubFolders(int folderId, {bool reset = false}) async {
    setState(() {
      isLoading = true;
    });

    if (reset) {
      currentPage = 1;
    } 

    await subFolderProvider?.fetchSubFolders(folderId: folderId, perPage: itemsPerPage, page: currentPage);
    totalPages = (subFolderProvider!.totalItems / itemsPerPage).ceil();

    setState(() {
      isLoading = false;
    });

    checkTokenExpiration(subFolderProvider);
  }

  Future<void> _fetchDocuments(int subfolderId, {bool reset = false}) async {
    setState(() {
      isLoading = true;
    });

    String? typeFile;
    bool? dateAsc;
    bool? dateDesc;
    bool? nameAsc;
    bool? nameDesc;

    switch (filterOption) {
      case 'pdf':
      case 'docx':
      case 'png':
      case 'jpg':
      case 'jpeg':
        typeFile = filterOption;
        break;
      case 'date_asc':
        dateAsc = true;
        break;
      case 'date_desc':
        dateDesc = true;
        break;
      case 'name_asc':
        nameAsc = true;
        break;
      case 'name_desc':
        nameDesc = true;
        break;
    }

    if (reset) {
      currentPage = 1;
    } 

    await fileProvider?.fetchDocuments(
      subfolderId: subfolderId,
      typeFile: typeFile,
      dateAsc: dateAsc,
      dateDesc: dateDesc,
      nameAsc: nameAsc,
      nameDesc: nameDesc,
      q: null,
      perPage: itemsPerPage,
      page: currentPage,
    );
    totalPages = (fileProvider!.totalItems / itemsPerPage).ceil();

    setState(() {
      isLoading = false;
    });

    checkTokenExpiration(fileProvider);
  }

  void _updateView({bool resetPage = false}) {
    if (showingDocuments && currentSubFolderId != null) {
      _fetchDocuments(currentSubFolderId!, reset: resetPage);
    } else if (showingSubFolders && currentFolderId != null) {
      _fetchSubFolders(currentFolderId!, reset: resetPage);
    } else {
      _fetchData(reset: resetPage);
    }
  }
  
  void checkTokenExpiration(dynamic provider) {
    if (provider.expiredToken) {
      provider.handleTokenExpiration();
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _requestPermissions() async {
    if (!io.Platform.isAndroid || !io.Platform.isIOS) {
      return;
    }

    var storageStatus = await Permission.storage.request();
    var cameraStatus = await Permission.camera.request();
    
    if (storageStatus.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFFFFF3F8), 
        content: Text('Permiso de almacenamiento denegado. Por favor, permita el acceso a almacenamiento para continuar.', style: TextStyle(color: Color(0xC3000022))),
      ));
    } else if (storageStatus.isPermanentlyDenied) {
      openAppSettings();
    }
    
    if (cameraStatus.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFFFFF3F8),
        content: Text('Permiso de cámara denegado. Por favor, permita el acceso a la cámara para continuar.', style: TextStyle(color: Color(0xC3000022))),
      ));
    } else if (cameraStatus.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = showingDocuments
        ? fileProvider?.file
        : showingSubFolders
            ? subFolderProvider?.subFolders
            : folderProvider?.folders;

    final List<int> perPageOptions = [5, 10, 20, 50];

    return Scaffold(
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xC3000022),),) 
       : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ToggleButtons(
              fillColor: const Color(0xC3000000),
              selectedColor: const Color(0xFFFFF3F8),
              isSelected: [viewType == 0, viewType == 1],
              onPressed: (int index) {
                setState(() {
                  viewType = index;
                });
              },
              children: const <Icon>[
                Icon(Icons.grid_view, color: Color(0xC3000022),),
                Icon(Icons.list, color: Color(0xC3000022),),
              ],
            ),
            const SizedBox(height: 8),
            if (showingDocuments) _buildFilterOptions(),
            const SizedBox(height: 8),
            isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xC3000022),))
                : Expanded(
                    child: viewType == 0 ? buildGridView(items!) : buildListView(items!),
                  ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child:   Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (showingDocuments)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xC3000022),),
                    onPressed: () {
                      setState(() {
                        showingDocuments = false;
                        currentSubFolderId = null;
                        currentPage = 1;
                      });
                      _fetchSubFolders(currentFolderId!, reset: true);
                    },
                  ),
                if (showingSubFolders && !showingDocuments)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xC3000022),),
                    onPressed: () {
                      setState(() {
                        showingSubFolders = false;
                        currentFolderId = null;
                        currentPage = 1;
                      });
                      _fetchData(reset: true);
                    },
                  ),
                if (!showingSubFolders && !showingDocuments)
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFFFFF3F8),
                    value: itemsPerPage,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          itemsPerPage = value;
                        });
                        _updateView(resetPage: true);
                      }
                    },
                    items: perPageOptions.map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value por página", style: const TextStyle(color: Color(0xC3000022))),
                      );
                    }).toList(),
                  ),
                if (showingSubFolders && !showingDocuments)
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFFFFF3F8),
                    value: itemsPerPage,
                    onChanged: (value) {
                      if (value != null && currentFolderId != null) {
                        setState(() {
                          itemsPerPage = value;
                        });
                        _updateView(resetPage: true);
                      }
                    },
                    items: perPageOptions.map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value por página", style: const TextStyle(color: Color(0xC3000022))),
                      );
                    }).toList(),
                  ),
                if (showingDocuments)
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFFFFF3F8),
                    value: itemsPerPage,
                    onChanged: (value) {
                      if (value != null && currentSubFolderId != null) {
                        setState(() {
                          itemsPerPage = value;
                        });
                        _updateView(resetPage: true);
                      }
                    },
                    items: perPageOptions.map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value por página", style: const TextStyle(color: Color(0xC3000022))),
                      );
                    }).toList(),
                  ),
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xC3000022),),
                      onPressed: currentPage > 1
                          ? () {
                              setState(() {
                                currentPage -= 1;
                              });
                              _updateView();
                            }
                          : null,
                    ),
                Text(
                    'Página $currentPage de $totalPages', style: const TextStyle(color: Color(0xC3000022))),
                    IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Color(0xC3000022),),
                  onPressed: currentPage < totalPages
                      ? () {
                          setState(() {
                            currentPage += 1;
                          });
                          _updateView();
                        }
                      : null,
                ),
              ],
            ),
            ),
          ],
        ),
      ),
      floatingActionButton: !kIsWeb && showingDocuments
      ? Padding(
        padding: const EdgeInsets.only(bottom: 55.0),
        child: FloatingActionButton(
          onPressed: _takePhoto,
          child: const Icon(Icons.camera_alt, color: Color(0xC3000022),),
        ),
      )
    : null,
    );
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    
    if (photo != null) {
      dynamic selectedFile = io.File(photo.path);
      
      bool shouldCrop = await _confirmImage(photo.path);

      if(shouldCrop){
        dynamic croppedFile = await ImageCropper().cropImage(
          sourcePath: photo.path,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          androidUiSettings: const AndroidUiSettings(
            toolbarTitle: 'Recortar Imagen',
            toolbarColor: Color(0xFFFFF3F8),
            toolbarWidgetColor: Color(0xC3000022),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          iosUiSettings: const IOSUiSettings(
            minimumAspectRatio: 1.0,
          ),
        );
        
        if (croppedFile != null) {
          selectedFile = io.File(croppedFile.path);
        }
      }

      setState(() {
        this.selectedFile = selectedFile;
      });
      
      final userId = user?['id'];
      if (userId != null) {
        _showLoadingDialog(context);
        await fileProvider?.addDocument(selectedFile.path, userId, currentSubFolderId!);
        
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Documento subido correctamente', style: TextStyle(color: Color(0xC3000022)))),
        );
        
        setState(() {
          selectedFile = null;
        });

        await _fetchDocuments(currentSubFolderId!, reset: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('No se pudo obtener el usuario actual', style: TextStyle(color: Color(0xC3000022)))),);
      }
  }
}

Future<bool> _confirmImage(String imagePath) async {
  return await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFFFFF3F8),
        title: const Text("Confirmar Imagen"),
        content: Image.file(io.File(imagePath)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Recortar", style: TextStyle(color: Color(0xC3000022))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Usar Imagen", style: TextStyle(color: Color(0xC3000022))),
          ),
        ],
      );
    },
  );
}

Future<void> _showLoadingDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // El diálogo no se puede descartar tocando fuera
    builder: (BuildContext context) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Subiendo imagen...')
          ],
        ),
      );
    },
  );
}

  Widget buildGridView(List<dynamic> items) {
    return RefreshIndicator(
      color: const Color(0xFFFFF3F8) ,
      backgroundColor: const Color(0xC3000022),
      onRefresh: () => _fetchData(reset: true),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 1 / 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _buildAddNewItemCard();
          }
          return buildItemCard(items[index]);
        },
      ),
    );
  }

  Widget buildListView(List<dynamic> items) {
    return RefreshIndicator(
      color: const Color(0xFFFFF3F8),
      backgroundColor: const Color(0xC3000022),
      onRefresh: () => _fetchData(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _buildAddNewItemCard();
          }
          return buildItemCard(items[index]);
        },
      ),
    );
  }

  Widget buildItemCard(dynamic item) {
    return InkWell(
      onTap: () async {
        if (!showingSubFolders && item.containsKey('folder_name')) {
          setState(() {
            showingSubFolders = true;
            currentFolderId = item['id'];
          });
          await _fetchSubFolders(item['id'], reset: true);
        } else if (!showingDocuments && item.containsKey('subfolder_name')) {
          setState(() {
            showingDocuments = true;
            currentSubFolderId = item['id'];
          });
          await _fetchDocuments(item['id']);
        } else if (showingDocuments && item.containsKey('document_name')) {
          _previewDocument(item);
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: const Color(0xFFFFF3F8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _getDocumentIcon(item['document_type'] ?? 'folder'),
                  Text(
                    item['folder_name'] ?? item['subfolder_name'] ?? item['document_name'],
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xC3000022),),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: PopupMenuButton<String>(
                color: const Color(0xFFFFF3F8),
                onSelected: (value) => _handleItemMenuAction(value, item),
                itemBuilder: (BuildContext context) {
                  List<String> choices = ['Editar', 'Borrar'];
                  if (item.containsKey('document_name')) {
                    choices.add('Descargar');
                  }
                  if (userType == 'Manager') {
                    choices.remove('Editar');
                    choices.remove('Borrar');
                  }
                  return choices.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child:Text(choice, style: const TextStyle(color: Color(0xC3000022)))
                  );
                  }).toList();
                },
                icon: const Icon(Icons.more_vert, color: Color(0xC3000022)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDocumentIcon(String documentType) {
    switch (documentType) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Color(0xC3000022),);
      case 'png':
        return const Icon(Icons.image, color: Color(0xC3000022),);
      case 'jpg':
        return const Icon(Icons.image, color: Color(0xC3000022),);
      case 'jpeg':
        return const Icon(Icons.image, color: Color(0xC3000022),);
      case 'docx':
        return const Icon(Icons.description, color: Color(0xC3000022),);
      case 'doc':
        return const Icon(Icons.description, color: Color(0xC3000022),);
      case 'xlsx':
        return const Icon(Icons.table_chart, color: Color(0xC3000022),);
      case 'xls':
        return const Icon(Icons.table_chart, color: Color(0xC3000022),);
      default:
        return const Icon(Icons.folder, color: Color(0xC3000022),);
    }
  }

  Widget _buildAddNewItemCard() {
    return InkWell(
      onTap: () => _showAddItemDialog(),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: const Color(0xFFFFF3F8) ,
        elevation: 4,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 50, color: Color(0xC3000022),),
              Text(showingDocuments
                  ? "Añadir Documento"
                  : showingSubFolders
                      ? "Añadir Subcarpeta"
                      : "Añadir Carpeta",style: const TextStyle(color: Color(0xC3000022)),),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    if (showingDocuments) {
      _showAddDocumentDialog();
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          String itemName = "";
          return AlertDialog(
            backgroundColor: const Color(0xFFFFF3F8),
            title: Text(showingSubFolders ? "Añadir Nueva Subcarpeta" : "Añadir Nueva Carpeta", style: const TextStyle(color: Color(0xC3000022))),
            content: TextField(
              onChanged: (value) => itemName = value,
              decoration: const InputDecoration(hintText: "Nombre"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022))),
              ),
              TextButton(
                onPressed: () {
                  if (itemName.isNotEmpty) {
                    if (showingSubFolders) {
                      subFolderProvider?.addSubFolder(itemName, currentFolderId!);
                    } else {
                      folderProvider?.addFolder(itemName, 1);
                    }
                    Navigator.of(context).pop();
                    _updateView(resetPage: true);  // <-- Update view after adding item
                  }
                },
                child: const Text("Crear", style: TextStyle(color: Color(0xC3000022))),
              ),
            ],
          );
        },
      );
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

  void _showAddDocumentDialog() async {
    final userId = user?['id'];
    bool isLoadFile = false;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el usuario actual', style: TextStyle(color: Color(0xC3000022)))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text("Añadir Nuevo Documento", style: TextStyle(color: Color(0xC3000022))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  selectedFile = await _selectFile();
                  setState(() {});
                },
                child: const Text("Seleccionar Archivo", style: TextStyle(color: Color(0xC3000022))),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022))),
            ),
            TextButton(
              onPressed: () async {
                if (selectedFile != null) {
                  setState(() {
                    isLoadFile = true;
                  });

                  if (kIsWeb) {
                    await fileProvider?.addDocument(
                      selectedFile,
                      userId,
                      currentSubFolderId!,
                    );
                    if (mounted) {
                      setState(() {
                        selectedFile = null;
                        isLoadFile = false;
                      });
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Documento subido correctamente', style: TextStyle(color: Color(0xC3000022)))),
                    );
                    Navigator.of(context).pop();
                    await _fetchDocuments(currentSubFolderId!);
                  } else {
                    await fileProvider?.addDocument(
                      (selectedFile as io.File).path,
                      userId,
                      currentSubFolderId!,
                    );
                    if (mounted) {
                      setState(() {
                        selectedFile = null;
                        isLoadFile = false;
                      });
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Documento subido correctamente', style: TextStyle(color: Color(0xC3000022)))),
                    );
                    Navigator.of(context).pop();
                    await _fetchDocuments(currentSubFolderId!);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Por favor seleccione un archivo', style: TextStyle(color: Color(0xC3000022)))),
                  );
                }
              },
              child: isLoadFile
                  ? const CircularProgressIndicator()
                  : const Text("Subir", style: TextStyle(color: Color(0xC3000022))),
            ),
          ],
        );
      },
    );
  }

  void _handleItemMenuAction(String choice, dynamic item) {
    if (choice == 'Editar' && userType != 'Manager') {
      _showEditItemDialog(item);
    } else if (choice == 'Borrar' && userType != 'Manager') {
      _showDeleteConfirmationDialog(item['id']);
    } else if (choice == 'Descargar') {
      _downloadDocument(item);
    }
  }


  void _showEditItemDialog(dynamic item) {
    if (showingDocuments) {
      _showEditDocumentDialog(item);
    } else {
      String itemName = item['folder_name'] ?? item['subfolder_name'] ?? '';
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFFF3F8),
            title: Text(showingSubFolders ? "Editar Subcarpeta" : "Editar Carpeta", style: const TextStyle(color: Color(0xC3000022))),
            content: TextField(
              controller: TextEditingController(text: itemName),
              onChanged: (value) => itemName = value,
              decoration: const InputDecoration(hintText: "Nombre"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022))),
              ),
              TextButton(
                onPressed: () {
                  if (itemName.isNotEmpty) {
                    if (showingSubFolders) {
                      subFolderProvider?.updateSubFolder(item['id'], itemName, currentFolderId!);
                    } else {
                      folderProvider?.updateFolder(item['id'], itemName, 1);
                    }
                    Navigator.of(context).pop();
                    _updateView(resetPage: true);
                  }
                },
                child: const Text("Guardar", style: TextStyle(color: Color(0xC3000022))),
              ),
            ],
          );
        },
      );
    }
  }

  void _showEditDocumentDialog(dynamic item) async {
    final documentId = item['id'];
    final userId = user?['id'];
    bool isLoadFile = false;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('No se pudo obtener el usuario actual', style: TextStyle(color: Color(0xC3000022)))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFF3F8),
              title: const Text("Editar Documento", style: TextStyle(color: Color(0xC3000022))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      selectedFile = await _selectFile();
                      setState(() {});
                    },
                    child: const Text("Seleccionar Archivo", style: TextStyle(color: Color(0xC3000022)) ),
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
                        final int parsedUserId = int.parse(userId);
                        if (kIsWeb) {
                          await fileProvider?.updateDocument(
                            documentId,
                            selectedFile,
                            parsedUserId,
                            currentSubFolderId!,
                          );
                        } else {
                          await fileProvider?.updateDocument(
                            documentId,
                            (selectedFile as io.File).path,
                            parsedUserId,
                            currentSubFolderId!,
                          );
                        }

                        if (mounted) {
                          setState(() {
                            selectedFile = null;
                            isLoadFile = false;
                          });
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Documento actualizado correctamente', style: TextStyle(color: Color(0xC3000022)),)),
                        );
                        Navigator.of(context).pop();
                        await _fetchDocuments(currentSubFolderId!);
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error updating document: $e');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Error al actualizar el documento', style: TextStyle(color: Color(0xC3000022)),)),
                        );
                        setState(() {
                          isLoadFile = false;
                        });
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: Color(0xFFFFF3F8), content: Text('Por favor seleccione un archivo', style: TextStyle(color: Color(0xC3000022)),)),
                      );
                    }
                  },
                  child: isLoadFile
                      ? const CircularProgressIndicator(backgroundColor: Color(0xC3000022),)
                      : const Text("Actualizar", style: TextStyle(color: Color(0xC3000022)),),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(int itemId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text("Confirmar Eliminación", style: TextStyle(color: Color(0xC3000022)),),
          content: const Text("¿Está seguro de que quiere borrar esta carpeta/subcarpeta/documento?", style: TextStyle(color: Color(0xC3000022)),),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Color(0xC3000022)),),
            ),
            TextButton(
              onPressed: () {
                if (showingDocuments) {
                  fileProvider?.deleteDocument(itemId);
                  _updateView(resetPage: true);
                } else if (showingSubFolders) {
                  subFolderProvider?.deleteSubFolder(itemId, currentFolderId!);
                  _updateView(resetPage: true);
                } else {
                  folderProvider?.deleteFolder(itemId);
                  _updateView(resetPage: true);
                }
                Navigator.of(context).pop();
                _updateView(resetPage: true);
              },
              child: const Text("Borrar", style: TextStyle(color: Color(0xC3000022)),),
            ),
          ],
        );
      },
    );
  }

  void _previewDocument(dynamic document) {
    if (document['document_type'] == 'pdf') {
      _showPdfPreview(document['document_content']);
    } else if (document['document_type'] == 'png' || document['document_type'] == 'jpeg' || document['document_type'] == 'jpg') {
      _showImagePreview(document['document_content']);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFF3F8),
          title: const Text('Vista previa no disponible', style: TextStyle(color: Color(0xC3000022)),),
          content: const Text('Vista previa no compatible para este tipo de documento', style: TextStyle(color: Color(0xC3000022)),),
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
          backgroundColor: const Color(0xC3000022),
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

  Future<void> _downloadDocument(dynamic document) async {
    String documentName = document['document_name'];
    String documentType = document['document_type'];
    String documentContentBase64 = document['document_content'];
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

  Widget _buildFilterOptions() {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            dropdownColor: const Color(0xFFFFF3F8),
            hint: const Text("Ordenar por", style: TextStyle(color: Color(0xC3000022)),),
            value: filterOption,
            onChanged: (String? newValue) {
              setState(() {
                filterOption = newValue;
              });
              _fetchDocuments(currentSubFolderId!);
            },
            items: <String>[
              'name_asc', 'name_desc',
              'date_asc', 'date_desc',
              'pdf', 'docx', 'png', 'jpg', 'jpeg'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(_getFilterText(value), style: const TextStyle(color: Color(0xC3000022)),),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getFilterText(String value) {
    switch (value) {
      case 'name_asc':
        return 'Nombre Ascendente';
      case 'name_desc':
        return 'Nombre Descendente';
      case 'date_asc':
        return 'Fecha Ascendente';
      case 'date_desc':
        return 'Fecha Descendente';
      case 'pdf':
        return 'PDF';
      case 'docx':
        return 'DOCX';
      case 'png':
        return 'PNG';
      case 'jpg':
        return 'JPG';
      case 'jpeg':
        return 'JPEG';
      default:
        return value;
    }
  }
}
