import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ocr/providers/convert_provider.dart';
import 'package:ocr/providers/ocr_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io' as io;


class Tools extends StatelessWidget {
  const Tools({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Convertir Formatos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Consumer<ConversionProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(backgroundColor: Color(0xC3000022),),
                        Text(provider.message),
                      ],
                    )
                  );
                }
                return buildConversionButtons(provider);
              },
            ),
            const SizedBox(height: 20),
            const Text('OCR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Consumer<OCRConversionProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(backgroundColor: Color(0xC3000022),),
                        Text(provider.message),
                      ],
                    )
                  );
                }
                return buildOCRButtons(provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildConversionButtons(ConversionProvider provider) {
    final List<Map<String, dynamic>> conversionOptions = [
      {'icon': Icons.file_copy, 'text': 'Convertir PDF a Word', 'format': 'docx', 'color': const Color(0xFFC3E3FD)},
      {'icon': Icons.grid_on, 'text': 'Convertir PDF a Excel', 'format': 'xlsx', 'color': const Color(0xFFC3E3FD)},
      {'icon': Icons.slideshow, 'text': 'Convertir PDF a PowerPoint', 'format': 'pptx', 'color': const Color(0xFFC3E3FD)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 1 / 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
      ),
      itemCount: conversionOptions.length,
      itemBuilder: (context, index) {
        var item = conversionOptions[index];
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFF3E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
          ),
          onPressed: () async {
            var selectedFile = await _selectFile();
            if (selectedFile != null) {
              if(kIsWeb){
                provider.convertFile(selectedFile, item['format']);
              }else{
                provider.convertFile((selectedFile as io.File).path, item['format']);
              }
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item['icon'], size: 48, color: item['color'],),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  item['text'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildOCRButtons(OCRConversionProvider ocrProvider) {


  final List<Map<String, dynamic>> ocrOptions = [
    {'icon': Icons.camera_alt, 'text': 'Convertir Foto a Texto (Word)', 'format': 'docx', 'color': const Color(0xFFC3E3FD) },
    {'icon': Icons.camera_alt, 'text': 'Convertir Foto a Texto (Excel)', 'format': 'xlsx', 'color': const Color(0xFFC3E3FD) },
    {'icon': Icons.camera_alt, 'text': 'Convertir Foto a Texto (PDF)', 'format': 'pptx', 'color': const Color(0xFFC3E3FD) },
  ];

   return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 1 / 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
      ),
    itemCount: ocrOptions.length,
    itemBuilder: (context, index) {
      var item = ocrOptions[index];
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF3E0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
        ),
        onPressed: () => !kIsWeb? _takePhotoAndConvert(ocrProvider, item['format'], context) : _takePhotoandConvertFile(ocrProvider , item['format']),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item['icon'], size: 48, color: item['color']),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                item['text'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _takePhotoandConvertFile(OCRConversionProvider ocrProvider, String extensionFile) async {
  var selectedFile = await _selectFile(isOCR: true);
  if(selectedFile != null){
    ocrProvider.performOCR(selectedFile, extensionFile);
  }
}

  Future<dynamic> _selectFile({bool isOCR = false}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: !isOCR ? ['pdf'] : ['png', 'jpeg', 'jpg'],
    );
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
 
   Future<void> _takePhotoAndConvert(OCRConversionProvider ocrProvider, String format, BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
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
        try {
          await ocrProvider.performOCR(croppedFile.path, format);
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
      }
    }
  }

}
